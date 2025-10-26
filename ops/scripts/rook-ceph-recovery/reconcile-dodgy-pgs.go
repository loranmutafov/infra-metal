package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"text/tabwriter"
)

type PGInfo struct {
	PGID            string `json:"pgid"`
	LastUpdate      string `json:"last_update"`
	LastComplete    string `json:"last_complete"`
	LastUserVersion int    `json:"last_user_version"`
	Stats           struct {
		StatSum struct {
			NumObjects int `json:"num_objects"`
		} `json:"stat_sum"`
		Version string `json:"version"`
	} `json:"stats"`
}

func main() {
	pgs := flag.String("pgs", "", "Comma-separated PG IDs")
	osds := flag.String("osds", "", "Comma-separated OSD IDs")
	flag.Parse()

	if *pgs == "" || *osds == "" {
		fmt.Println("Usage: go run reconcile-dodgy-pgs.go -pgs=1.1a,1.1b -osds=2,3,4")
		return
	}

	namespace := "rook-ceph"
	pgIDs := strings.Split(*pgs, ",")
	osdIDs := parseOSDs(*osds)

	// Find maintenance pods for OSDs
	osdPods := make(map[int]string)
	for _, id := range osdIDs {
		pod := findMaintenancePod(namespace, id)
		if pod == "" {
			fmt.Printf("Failed to find maintenance pod for OSD %d\n", id)
			continue
		}
		osdPods[id] = pod
	}

	for _, pgid := range pgIDs {
		fmt.Printf("\nProcessing PG %s\n", pgid)

		// Query cluster using kubectl rook-ceph plugin
		clusterJSON := queryCluster(pgid)
		saveJSON(fmt.Sprintf("pg_%s_cluster.json", pgid), clusterJSON)

		var cr struct {
			Info PGInfo `json:"info"`
		}
		err := json.Unmarshal([]byte(clusterJSON), &cr)
		if err != nil {
			fmt.Printf("Error unmarshaling cluster JSON for PG %s: %v\n", pgid, err)
			continue
		}
		cluster := cr.Info

		// Query OSDs
		osdInfos := make(map[int]PGInfo)
		for id, pod := range osdPods {
			osdJSON := queryOSD(namespace, pod, id, pgid)
			saveJSON(fmt.Sprintf("pg_%s_osd_%d.json", pgid, id), osdJSON)

			var info PGInfo
			err := json.Unmarshal([]byte(osdJSON), &info)
			if err != nil {
				fmt.Printf("Error unmarshaling OSD %d JSON for PG %s: %v\n", id, pgid, err)
				continue
			}
			osdInfos[id] = info
		}

		// Highlight differences
		compareAndPrint(pgid, cluster, osdInfos, osdIDs)

		// Assume most up-to-date
		mostRecent := findMostRecent(cluster, osdInfos)
		fmt.Printf("Most up-to-date: %s\n", mostRecent)
	}
}

func parseOSDs(osdStr string) []int {
	var ids []int
	for _, s := range strings.Split(osdStr, ",") {
		id, err := strconv.Atoi(strings.TrimSpace(s))
		if err == nil {
			ids = append(ids, id)
		}
	}
	return ids
}

func findMaintenancePod(ns string, osd int) string {
	osdStr := strconv.Itoa(osd)
	cmd := exec.Command("kubectl", "get", "pods", "-n", ns, "--no-headers", "-o", "custom-columns=NAME:.metadata.name")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	for _, line := range lines {
		if strings.Contains(line, "rook-ceph-osd-"+osdStr+"-maintenance-") {
			return line
		}
	}
	return ""
}

func queryCluster(pgid string) string {
	cmd := exec.Command("kubectl", "rook-ceph", "ceph", "pg", pgid, "query")
	out, err := cmd.Output()
	if err != nil {
		return "{}"
	}
	return string(out)
}

func queryOSD(ns, pod string, osd int, pgid string) string {
	path := "/var/lib/ceph/osd/ceph-" + strconv.Itoa(osd)
	cmd := exec.Command("kubectl", "-n", ns, "exec", pod, "--", "ceph-objectstore-tool", "--data-path", path, "--pgid", pgid, "--op", "info")
	out, err := cmd.Output()
	if err != nil {
		return "{}"
	}
	return string(out)
}

func saveJSON(file string, data string) {
	err := os.WriteFile(file, []byte(data), 0644)
	if err != nil {
		fmt.Printf("Failed to save %s: %v\n", file, err)
	}
}

func compareAndPrint(pgid string, cluster PGInfo, osdInfos map[int]PGInfo, osdIDs []int) {
	all := map[string]PGInfo{"cluster": cluster}
	for id, info := range osdInfos {
		all[fmt.Sprintf("osd%d", id)] = info
	}

	keys := []string{"cluster"}
	for _, id := range osdIDs {
		if _, ok := osdInfos[id]; ok {
			keys = append(keys, fmt.Sprintf("osd%d", id))
		}
	}

	var buf bytes.Buffer
	buf.WriteString("Field\t")
	for _, k := range keys {
		buf.WriteString(k + "\t")
	}
	buf.WriteString("\n")

	fields := []struct {
		name string
		get  func(PGInfo) string
	}{
		{"last_update", func(i PGInfo) string { return i.LastUpdate }},
		{"last_complete", func(i PGInfo) string { return i.LastComplete }},
		{"last_user_version", func(i PGInfo) string { return strconv.Itoa(i.LastUserVersion) }},
		{"num_objects", func(i PGInfo) string { return strconv.Itoa(i.Stats.StatSum.NumObjects) }},
		{"stats.version", func(i PGInfo) string { return i.Stats.Version }},
	}

	for _, f := range fields {
		buf.WriteString(f.name + "\t")
		vals := make([]string, len(keys))
		for i, k := range keys {
			vals[i] = f.get(all[k])
		}
		prev := ""
		for _, v := range vals {
			if v != prev && prev != "" {
				buf.WriteString("*" + v + "\t") // Highlight diff
			} else {
				buf.WriteString(v + "\t")
			}
			prev = v
		}
		buf.WriteString("\n")
	}

	w := tabwriter.NewWriter(os.Stdout, 1, 1, 1, ' ', 0)
	_, _ = fmt.Fprintln(w, buf.String())
	_ = w.Flush()
}

func findMostRecent(cluster PGInfo, osdInfos map[int]PGInfo) string {
	type Entry struct {
		name string
		ep   int
		ver  int
	}

	entries := []Entry{{name: "cluster", ep: parseEpoch(cluster.LastUpdate), ver: parseVersion(cluster.LastUpdate)}}
	for id, info := range osdInfos {
		entries = append(entries, Entry{name: fmt.Sprintf("osd%d", id), ep: parseEpoch(info.LastUpdate), ver: parseVersion(info.LastUpdate)})
	}

	sort.Slice(entries, func(i, j int) bool {
		if entries[i].ep != entries[j].ep {
			return entries[i].ep > entries[j].ep
		}
		return entries[i].ver > entries[j].ver
	})

	return entries[0].name
}

func parseEpoch(s string) int {
	parts := strings.Split(s, "'")
	if len(parts) == 2 {
		ep, _ := strconv.Atoi(parts[0])
		return ep
	}
	return 0
}

func parseVersion(s string) int {
	parts := strings.Split(s, "'")
	if len(parts) == 2 {
		ver, _ := strconv.Atoi(parts[1])
		return ver
	}
	return 0
}
