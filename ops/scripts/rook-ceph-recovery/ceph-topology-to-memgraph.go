package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/neo4j/neo4j-go-driver/v5/neo4j"
)

type PGObjectPair struct {
	PGID    string   `json:"pg_id"`
	Objects []string `json:"objects"`
}

type ObjectData []interface{}

// MemgraphClient wraps the driver and session for reuse
type MemgraphClient struct {
	driver  neo4j.DriverWithContext
	session neo4j.SessionWithContext
	logger  *log.Logger
}

func NewMemgraphClient(address, username, password string, logger *log.Logger) (*MemgraphClient, error) {
	logger.Printf("Connecting to Memgraph at %s", address)
	fmt.Printf("Connecting to Memgraph at %s\n", address)

	uri := fmt.Sprintf("bolt://%s", address)

	auth := neo4j.NoAuth()
	if username != "" {
		auth = neo4j.BasicAuth(username, password, "")
	}

	driver, err := neo4j.NewDriverWithContext(uri, auth, func(config *neo4j.Config) {
		config.MaxConnectionLifetime = 30 * time.Minute
		config.MaxConnectionPoolSize = 50
		config.ConnectionAcquisitionTimeout = 2 * time.Minute
		// Enable keep-alive for long-lived connections
		config.SocketKeepalive = true
	})

	if err != nil {
		return nil, fmt.Errorf("failed to create driver: %v", err)
	}

	// Create a long-lived session with write access
	session := driver.NewSession(context.Background(), neo4j.SessionConfig{
		AccessMode: neo4j.AccessModeWrite,
	})

	client := &MemgraphClient{
		driver:  driver,
		session: session,
		logger:  logger,
	}

	return client, nil
}

func (mc *MemgraphClient) Close(ctx context.Context) error {
	if mc.session != nil {
		mc.session.Close(ctx)
	}
	if mc.driver != nil {
		return mc.driver.Close(ctx)
	}
	return nil
}

func (mc *MemgraphClient) TestConnection(ctx context.Context) error {
	mc.logger.Println("Testing Memgraph connection...")
	fmt.Println("Testing Memgraph connection...")

	// Test basic connectivity
	result, err := mc.session.Run(ctx, "RETURN 'Connection successful' as message", nil)
	if err != nil {
		return fmt.Errorf("failed to test connection: %v", err)
	}

	if result.Next(ctx) {
		record := result.Record()
		message, _ := record.Get("message")
		mc.logger.Printf("Connection test result: %v", message)
		fmt.Printf("Connection test result: %v\n", message)
	}

	if err := result.Err(); err != nil {
		return fmt.Errorf("error in connection test: %v", err)
	}

	mc.logger.Println("Memgraph connection OK")
	fmt.Println("Memgraph connection OK")
	return nil
}

func (mc *MemgraphClient) CreateOSDNode(ctx context.Context, osdID string) error {
	mc.logger.Printf("Creating OSD node for ID %s", osdID)
	fmt.Printf("Creating OSD node for ID %s\n", osdID)

	query := `
		MERGE (o:OSD {id: $osd_id})
		ON CREATE SET
			o.created_at = timestamp(),
			o.name = $osd_name
		RETURN o.id as id, o.name as name
	`

	params := map[string]interface{}{
		"osd_id":   osdID,
		"osd_name": fmt.Sprintf("osd-%s", osdID),
	}

	result, err := mc.session.Run(ctx, query, params)
	if err != nil {
		return fmt.Errorf("failed to create OSD node: %v", err)
	}

	if result.Next(ctx) {
		record := result.Record()
		id, _ := record.Get("id")
		name, _ := record.Get("name")
		mc.logger.Printf("Created OSD node: id=%v, name=%v", id, name)
		fmt.Printf("Created OSD node: id=%v, name=%v\n", id, name)
	}

	if err := result.Err(); err != nil {
		return fmt.Errorf("error creating OSD node: %v", err)
	}

	fmt.Println("OSD node created successfully")
	return nil
}

func (mc *MemgraphClient) ProcessPGObjects(ctx context.Context, pairs []PGObjectPair, osdID string) error {
	for i, pair := range pairs {
		mc.logger.Printf("Processing PG %d/%d: %s", i+1, len(pairs), pair.PGID)
		fmt.Printf("Processing PG %d/%d: %s with %d objects\n", i+1, len(pairs), pair.PGID, len(pair.Objects))

		if err := mc.processSinglePG(ctx, pair, osdID); err != nil {
			return fmt.Errorf("failed to process PG %s: %v", pair.PGID, err)
		}
	}
	return nil
}

func (mc *MemgraphClient) processSinglePG(ctx context.Context, pair PGObjectPair, osdID string) error {
	// Create PG node and relationship to OSD
	pgQuery := `
		MATCH (o:OSD {id: $osd_id})
		MERGE (p:PG {id: $pg_id})
		ON CREATE SET
			p.created_at = timestamp(),
			p.name = $pg_name
		MERGE (o)-[:CONTAINS]->(p)
		RETURN p.id as pg_id, p.name as pg_name
	`

	pgParams := map[string]interface{}{
		"osd_id":  osdID,
		"pg_id":   pair.PGID,
		"pg_name": fmt.Sprintf("PG %s", pair.PGID),
	}

	result, err := mc.session.Run(ctx, pgQuery, pgParams)
	if err != nil {
		return fmt.Errorf("failed to create PG node: %v", err)
	}

	if result.Next(ctx) {
		record := result.Record()
		pgID, _ := record.Get("pg_id")
		pgName, _ := record.Get("pg_name")
		mc.logger.Printf("Created PG node: id=%v, name=%v", pgID, pgName)
	}

	if err := result.Err(); err != nil {
		return fmt.Errorf("error creating PG node: %v", err)
	}

	// Process objects in batches
	const batchSize = 200
	for i := 0; i < len(pair.Objects); i += batchSize {
		end := i + batchSize
		if end > len(pair.Objects) {
			end = len(pair.Objects)
		}

		batch := pair.Objects[i:end]
		if err := mc.processBatchObjects(ctx, batch, pair.PGID, osdID); err != nil {
			return fmt.Errorf("failed to process batch %d-%d for PG %s: %v", i, end, pair.PGID, err)
		}

		fmt.Printf("Processed batch %d-%d (%d objects) for PG %s\n", i, end, len(batch), pair.PGID)
	}

	mc.logger.Printf("Successfully processed %d objects for PG %s", len(pair.Objects), pair.PGID)
	return nil
}

func (mc *MemgraphClient) processBatchObjects(ctx context.Context, objects []string, pgID, osdID string) error {
	// Filter out empty objects first
	var validObjects []string
	for _, obj := range objects {
		if obj != "" {
			validObjects = append(validObjects, obj)
		}
	}

	if len(validObjects) == 0 {
		return nil
	}

	// Use a single write transaction with UNWIND for batch processing
	_, err := mc.session.ExecuteWrite(ctx, func(tx neo4j.ManagedTransaction) (interface{}, error) {
		// Prepare batch data
		var batchData []map[string]interface{}
		for _, objectName := range validObjects {
			batchData = append(batchData, map[string]interface{}{
				"object_id":          objectName,
				"unique_object_id":   fmt.Sprintf("%s-%s", osdID, objectName),
				"object_name":        fmt.Sprintf("Obj %s", objectName),
				"unique_object_name": fmt.Sprintf("[%s] Obj %s", osdID, objectName),
			})
		}

		// Single batch query using UNWIND
		query := `
			MATCH (o:OSD {id: $osd_id}) 
			MATCH (p:PG {id: $pg_id})
			UNWIND $batch_data AS item
			MERGE (b:Object {id: item.object_id})-[:IS]->(ub:UniqueObject {id: item.unique_object_id})
			ON CREATE SET 
				b.created_at = timestamp(), 
				b.name = item.object_name,
				ub.created_at = timestamp(), 
				ub.name = item.unique_object_name
			MERGE (o)-[:CONTAINS]->(ub)
			MERGE (p)-[:CONTAINS]->(ub)
			MERGE (p)-[:CONTAINS]->(b)
		`

		params := map[string]interface{}{
			"osd_id":     osdID,
			"pg_id":      pgID,
			"batch_data": batchData,
		}

		result, err := tx.Run(ctx, query, params)
		if err != nil {
			return nil, fmt.Errorf("failed to create batch objects: %v", err)
		}

		// Consume the result
		summary, err := result.Consume(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to consume batch result: %v", err)
		}

		mc.logger.Printf("Batch processed: %d objects, nodes created: %d, relationships created: %d",
			len(validObjects), summary.Counters().NodesCreated(), summary.Counters().RelationshipsCreated())

		return nil, nil
	})

	if err != nil {
		return err
	}

	fmt.Printf("Created %d objects in PG %s\n", len(validObjects), pgID)
	mc.logger.Printf("Created %d objects in PG %s", len(validObjects), pgID)

	return nil
}

func (mc *MemgraphClient) CreateSnapshot(ctx context.Context) error {
	mc.logger.Println("Creating snapshot...")
	fmt.Println("Creating snapshot...")

	result, err := mc.session.Run(ctx, "CALL mg.create_snapshot()", nil)
	if err != nil {
		return fmt.Errorf("failed to create snapshot: %v", err)
	}

	// Consume any results
	for result.Next(ctx) {
		// Process snapshot result if any
	}

	if err := result.Err(); err != nil {
		return fmt.Errorf("error creating snapshot: %v", err)
	}

	mc.logger.Println("Snapshot created successfully")
	fmt.Println("Snapshot created successfully")
	return nil
}

// GetStats returns database statistics for monitoring
func (mc *MemgraphClient) GetStats(ctx context.Context) error {
	queries := []struct {
		name  string
		query string
	}{
		{"OSD Count", "MATCH (o:OSD) RETURN count(o) as count"},
		{"PG Count", "MATCH (p:PG) RETURN count(p) as count"},
		{"Object Count", "MATCH (obj:Object) RETURN count(obj) as count"},
		{"UniqueObject Count", "MATCH (uo:UniqueObject) RETURN count(uo) as count"},
		{"Relationship Count", "MATCH ()-[r]->() RETURN count(r) as count"},
	}

	fmt.Println("\n=== Database Statistics ===")
	mc.logger.Println("Database Statistics:")

	for _, q := range queries {
		result, err := mc.session.Run(ctx, q.query, nil)
		if err != nil {
			mc.logger.Printf("Error getting %s: %v", q.name, err)
			continue
		}

		if result.Next(ctx) {
			record := result.Record()
			count, _ := record.Get("count")
			fmt.Printf("%s: %v\n", q.name, count)
			mc.logger.Printf("%s: %v", q.name, count)
		}

		if err := result.Err(); err != nil {
			mc.logger.Printf("Error in %s query: %v", q.name, err)
		}
	}

	fmt.Println("=============================\n")
	return nil
}

func main() {
	if len(os.Args) != 3 {
		_, _ = fmt.Fprintf(os.Stderr, "Usage: %s <osd_pod_name> <namespace> <memgraph_host:port> <memgraph_user>\n", os.Args[0])
		_, _ = fmt.Fprintf(os.Stderr, "Example: %s rook-ceph-osd-0 rook-ceph localhost:7687 \"\"\n", os.Args[0])
		os.Exit(1)
	}

	osdPod := os.Args[1]
	namespace := os.Args[2]
	memgraphAddress := "localhost:7687"
	memgraphUser := ""

	// Check for required commands
	requiredCmds := []string{"kubectl"}
	for _, cmd := range requiredCmds {
		if !commandExists(cmd) {
			log.Fatalf("Error: %s is required but not installed", cmd)
		}
	}

	// Generate unique hash for deduplication
	dedupeHash, err := generateRandomHex(8)
	if err != nil {
		log.Fatalf("Error generating random hash: %v", err)
	}

	// Extract OSD ID from pod name
	osdID, err := extractOSDID(osdPod)
	if err != nil {
		log.Fatalf("Error extracting OSD ID: %v", err)
	}

	dataPath := fmt.Sprintf("/var/lib/ceph/osd/ceph-%s", osdID)
	logFile := fmt.Sprintf("/tmp/memgraph_insert_%s.log", dedupeHash)
	tempCypherDir := fmt.Sprintf("/tmp/cypher_%s", dedupeHash)

	// Create log file and temp directory
	if err := createLogFile(logFile); err != nil {
		log.Fatalf("Error creating log file: %v", err)
	}

	if err := os.MkdirAll(tempCypherDir, 0755); err != nil {
		log.Fatalf("Error creating temp directory: %v", err)
	}

	logf, err := os.OpenFile(logFile, os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Fatalf("Error opening log file: %v", err)
	}
	defer logf.Close()

	logger := log.New(logf, "", log.LstdFlags)

	// Validate OSD pod exists
	if err := validateOSDPod(osdPod, namespace); err != nil {
		log.Fatalf("Error: %v", err)
	}

	// Create Memgraph client with long-lived session
	ctx := context.Background()
	client, err := NewMemgraphClient(memgraphAddress, memgraphUser, "", logger)
	if err != nil {
		log.Fatalf("Error creating Memgraph client: %v", err)
	}
	defer client.Close(ctx)

	// Test connection
	if err := client.TestConnection(ctx); err != nil {
		log.Fatalf("Error testing Memgraph connection: %v", err)
	}

	// Create OSD node in Memgraph
	if err := client.CreateOSDNode(ctx, osdID); err != nil {
		log.Fatalf("Error creating OSD node: %v", err)
	}

	// Get PG list from OSD
	pgsFilepath := filepath.Join(tempCypherDir, fmt.Sprintf("osd-%s-pgs.json", osdID))
	objectList, err := getObjectList(osdPod, namespace, dataPath, pgsFilepath, logger)
	if err != nil {
		log.Fatalf("Error getting object list: %v", err)
	}

	// Parse and process objects
	pgObjectPairs, err := parseObjectList(objectList, logger)
	if err != nil {
		log.Fatalf("Error parsing object list: %v", err)
	}

	// Process PG objects
	if err := client.ProcessPGObjects(ctx, pgObjectPairs, osdID); err != nil {
		log.Fatalf("Error processing PG objects: %v", err)
	}

	// Get final statistics
	if err := client.GetStats(ctx); err != nil {
		log.Fatalf("Error getting final stats: %v", err)
	}

	// Create snapshot
	if err := client.CreateSnapshot(ctx); err != nil {
		log.Fatalf("Error creating snapshot: %v", err)
	}

	fmt.Printf("Processing complete for OSD pod %s. Logs in %s\n", osdPod, logFile)
	fmt.Printf("PGs recorded locally: %s\n", pgsFilepath)
}

// Utility functions (unchanged from original)
func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func generateRandomHex(n int) (string, error) {
	bytes := make([]byte, n)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func extractOSDID(osdPod string) (string, error) {
	re := regexp.MustCompile(`.*osd-([0-9]+).*`)
	matches := re.FindStringSubmatch(osdPod)
	if len(matches) < 2 {
		return "", fmt.Errorf("cannot extract OSD ID from pod name: %s", osdPod)
	}
	return matches[1], nil
}

func createLogFile(logFile string) error {
	f, err := os.Create(logFile)
	if err != nil {
		return err
	}
	return f.Close()
}

func validateOSDPod(osdPod, namespace string) error {
	cmd := exec.Command("kubectl", "-n", namespace, "get", "pod", osdPod)
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("OSD pod %s not found in namespace %s", osdPod, namespace)
	}
	return nil
}

func getObjectList(osdPod, namespace, dataPath, pgsFilepath string, logger *log.Logger) (string, error) {
	cmd := exec.Command("kubectl", "-n", namespace, "exec", osdPod, "--", "ceph-objectstore-tool", "--data-path", dataPath, "--op", "list")

	output, err := cmd.Output()
	if err != nil {
		logger.Printf("Error listing objects: %v", err)
		return "", fmt.Errorf("failed to list objects")
	}

	// Write to file
	if err := os.WriteFile(pgsFilepath, output, 0644); err != nil {
		return "", fmt.Errorf("failed to write PGs file: %v", err)
	}

	objectList := string(output)
	logger.Printf("Objects in OSD: %s", objectList)
	fmt.Printf("Objects in OSD: %s\n", objectList)

	return objectList, nil
}

func parseObjectList(objectList string, logger *log.Logger) ([]PGObjectPair, error) {
	logger.Println("Splitting object list into PGs...")
	fmt.Println("Splitting object list into PGs...")

	// Parse each line as a separate JSON array
	lines := strings.Split(strings.TrimSpace(objectList), "\n")
	var objects []ObjectData

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		var obj ObjectData
		if err := json.Unmarshal([]byte(line), &obj); err != nil {
			logger.Printf("Warning: failed to parse line: %s, error: %v", line, err)
			continue
		}
		objects = append(objects, obj)
	}

	// Group by PG ID
	pgMap := make(map[string][]string)
	for _, obj := range objects {
		if len(obj) < 2 {
			continue
		}

		pgID, ok := obj[0].(string)
		if !ok {
			continue
		}

		objInfo, ok := obj[1].(map[string]interface{})
		if !ok {
			continue
		}

		oid, ok := objInfo["oid"].(string)
		if !ok || oid == "" {
			continue // Skip empty OIDs
		}

		pgMap[pgID] = append(pgMap[pgID], oid)
		fmt.Printf("Found object: %s in PG: %s\n", oid, pgID)
	}

	// Convert to slice
	var pairs []PGObjectPair
	for pgID, objects := range pgMap {
		pairs = append(pairs, PGObjectPair{
			PGID:    pgID,
			Objects: objects,
		})
	}

	logger.Printf("Parsed %d PGs with objects", len(pairs))
	fmt.Printf("Parsed %d PGs with objects\n", len(pairs))

	return pairs, nil
}
