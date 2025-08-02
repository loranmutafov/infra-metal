package main

import (
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
)

type PGObjectPair struct {
	PGID    string   `json:"pg_id"`
	Objects []string `json:"objects"`
}

type ObjectData []interface{}

func main() {
	if len(os.Args) != 4 {
		_, _ = fmt.Fprintf(os.Stderr, "Usage: %s <osd_pod_name> <namespace> <memgraph_container_name>\n", os.Args[0])
		os.Exit(1)
	}

	osdPod := os.Args[1]
	namespace := os.Args[2]
	memgraphContainer := os.Args[3]

	// Check for required commands
	requiredCmds := []string{"kubectl", "docker"}
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

	// Validate Memgraph container is running
	if err := validateMemgraphContainer(memgraphContainer); err != nil {
		log.Fatalf("Error: %v", err)
	}

	// Check Memgraph storage and connectivity
	if err := checkMemgraphSetup(memgraphContainer, logger); err != nil {
		log.Fatalf("Error: %v", err)
	}

	// Create OSD node in Memgraph
	if err := createOSDNode(memgraphContainer, osdID, logger); err != nil {
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
	if err := processPGObjects(pgObjectPairs, memgraphContainer, osdID, tempCypherDir, logger); err != nil {
		log.Fatalf("Error processing PG objects: %v", err)
	}

	// Force snapshot
	if err := forceSnapshot(memgraphContainer, tempCypherDir, logger); err != nil {
		log.Fatalf("Error forcing snapshot: %v", err)
	}

	fmt.Printf("Processing complete for OSD pod %s. Logs in %s\n", osdPod, logFile)
	fmt.Printf("PGs recorded locally: %s\n", pgsFilepath)
}

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

func cleanup(tempDir string) {
	os.RemoveAll(tempDir)
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

func validateMemgraphContainer(container string) error {
	cmd := exec.Command("docker", "ps")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check docker containers: %v", err)
	}
	if !strings.Contains(string(output), container) {
		return fmt.Errorf("Memgraph container %s not running", container)
	}
	return nil
}

func checkMemgraphSetup(container string, logger *log.Logger) error {
	logger.Println("Checking Memgraph storage directory...")
	fmt.Println("Checking Memgraph storage directory...")

	// Check storage directory
	cmd := exec.Command("docker", "exec", container, "ls", "-ld", "/var/lib/memgraph")
	output, err := cmd.CombinedOutput()
	logger.Printf("Storage check output: %s", string(output))
	if err != nil {
		logger.Printf("Error checking storage: %v", err)
		return fmt.Errorf("cannot access /var/lib/memgraph in container. Check logs")
	}

	// Check for WAL and snapshot files
	logger.Println("Checking for WAL and snapshot files...")
	cmd = exec.Command("docker", "exec", container, "ls", "-l", "/var/lib/memgraph/*.wal", "/var/lib/memgraph/*.snapshot")
	output, err = cmd.CombinedOutput()
	logger.Printf("WAL/snapshot check output: %s", string(output))

	// Test connectivity
	logger.Println("Testing Memgraph connectivity...")
	fmt.Println("Testing Memgraph connectivity...")
	cmd = exec.Command("docker", "exec", "-i", container, "mgconsole")
	cmd.Stdin = strings.NewReader("SHOW CONFIG;\n")
	output, err = cmd.CombinedOutput()
	logger.Printf("Connectivity test output: %s", string(output))
	if err != nil {
		logger.Printf("Error testing connectivity: %v", err)
		return fmt.Errorf("failed to connect to Memgraph. Check logs")
	}

	logger.Println("Memgraph connectivity OK")
	fmt.Println("Memgraph connectivity OK")
	return nil
}

func createOSDNode(container, osdID string, logger *log.Logger) error {
	logger.Printf("Creating OSD node for ID %s", osdID)
	fmt.Printf("Creating OSD node for ID %s\n", osdID)

	query := fmt.Sprintf(`
		BEGIN;
			MERGE (o:OSD {id: '%s'}) ON CREATE SET o.created_at = timestamp(), o.name = 'osd-%s';
		COMMIT;`,
		osdID, osdID,
	)

	cmd := exec.Command("docker", "exec", "-i", container, "mgconsole", "--host", "localhost", "--port", "7687")
	cmd.Stdin = strings.NewReader(query)
	output, err := cmd.CombinedOutput()
	logger.Printf("OSD node creation output: %s", string(output))

	if err != nil {
		logger.Printf("Error creating OSD node: %v", err)
		return fmt.Errorf("failed to execute OSD node creation query")
	}

	fmt.Println("OSD node created")
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

	// Parse JSON array
	var objects []ObjectData
	if err := json.Unmarshal([]byte(objectList), &objects); err != nil {
		return nil, fmt.Errorf("failed to parse object list JSON: %v", err)
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
		if !ok {
			continue
		}

		pgMap[pgID] = append(pgMap[pgID], oid)
	}

	// Convert to slice
	var pairs []PGObjectPair
	for pgID, objects := range pgMap {
		pairs = append(pairs, PGObjectPair{
			PGID:    pgID,
			Objects: objects,
		})
	}

	logger.Println("Processing PG objects...")
	fmt.Println("Processing PG objects...")

	return pairs, nil
}

func processPGObjects(pairs []PGObjectPair, container, osdID, tempDir string, logger *log.Logger) error {
	for _, pair := range pairs {
		if err := processSinglePG(pair, container, osdID, tempDir, logger); err != nil {
			return err
		}
	}
	return nil
}

func processSinglePG(pair PGObjectPair, container, osdID, tempDir string, logger *log.Logger) error {
	objectCount := len(pair.Objects)
	logger.Printf("Generating query for PG %s", pair.PGID)

	// Create PG node and relationship
	pgQuery := fmt.Sprintf(`
		BEGIN;
		MATCH (o:OSD {id: '%s'})
			MERGE (p:PG {id: '%s'}) ON CREATE SET p.created_at = timestamp(), p.name = 'PG %s'
			MERGE (o)-[:CONTAINS]->(p);
		COMMIT;`,
		osdID, pair.PGID, pair.PGID,
	)

	cmd := exec.Command("docker", "exec", "-i", container, "mgconsole", "--host", "localhost", "--port", "7687")
	cmd.Stdin = strings.NewReader(pgQuery)
	output, err := cmd.CombinedOutput()
	logger.Printf("PG creation output: %s", string(output))
	if err != nil {
		logger.Printf("Error creating PG: %v", err)
		return fmt.Errorf("failed to create PG %s", pair.PGID)
	}

	// Process objects in batches to avoid memory issues
	const batchSize = 100
	for i := 0; i < len(pair.Objects); i += batchSize {
		end := i + batchSize
		if end > len(pair.Objects) {
			end = len(pair.Objects)
		}

		batch := pair.Objects[i:end]
		if err := processBatchObjects(batch, pair.PGID, container, osdID, logger); err != nil {
			return err
		}
	}

	logger.Printf("Inserted %d objects for PG %s", objectCount, pair.PGID)
	return nil
}

func processBatchObjects(objects []string, pgID, container, osdID string, logger *log.Logger) error {
	var queryBuilder strings.Builder
	queryBuilder.WriteString("BEGIN;")

	for _, objectName := range objects {
		if objectName == "" {
			continue
		}

		logger.Printf("Inserting into PG %s -> Object %s", pgID, objectName)

		queryBuilder.WriteString(fmt.Sprintf(`
			MATCH (o:OSD {id: '%s'}) MATCH (p:PG {id: '%s'})
				MERGE (b:Object {id: '%s'})-[:IS]->(ub:UniqueObject {id: '%s-%s'})
				ON CREATE SET
					b.created_at = timestamp(),
					b.name = 'Obj %s',
					ub.created_at = timestamp(),
					ub.name = '[%s] Obj %s'
				MERGE (o)-[:CONTAINS]->(ub)
				MERGE (p)-[:CONTAINS]->(ub)
				MERGE (p)-[:CONTAINS]->(b);
			`,
			osdID, pgID, objectName, osdID, objectName, objectName, osdID, objectName,
		))
	}

	queryBuilder.WriteString("COMMIT;")

	cmd := exec.Command("docker", "exec", "-i", container, "mgconsole", "--host", "localhost", "--port", "7687")
	cmd.Stdin = strings.NewReader(queryBuilder.String())
	output, err := cmd.CombinedOutput()
	logger.Printf("Batch insert output: %s", string(output))

	if err != nil {
		logger.Printf("Error inserting batch for PG %s: %v", pgID, err)
		return fmt.Errorf("failed to insert objects for PG %s", pgID)
	}

	return nil
}

func forceSnapshot(container, tempDir string, logger *log.Logger) error {
	logger.Println("Forcing snapshot...")
	fmt.Println("Forcing snapshot...")

	snapshotFile := filepath.Join(tempDir, "snapshot.cypher")
	if err := os.WriteFile(snapshotFile, []byte("CALL mg.create_snapshot();"), 0644); err != nil {
		return fmt.Errorf("failed to create snapshot file: %v", err)
	}

	cmd := exec.Command("docker", "exec", "-i", container, "mgconsole", "--host", "localhost", "--port", "7687")

	file, err := os.Open(snapshotFile)
	if err != nil {
		return fmt.Errorf("failed to open snapshot file: %v", err)
	}
	defer file.Close()

	cmd.Stdin = file
	output, err := cmd.CombinedOutput()
	logger.Printf("Snapshot output: %s", string(output))

	if err != nil {
		logger.Printf("Error creating snapshot: %v", err)
		return fmt.Errorf("failed to create snapshot")
	}

	return nil
}
