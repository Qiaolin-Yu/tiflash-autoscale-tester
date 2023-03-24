package main

import (
	"log"
	"testing"
	"time"
)

func TestAutoscale(t *testing.T) {
	config := NewDefaultConfig()
	log.Println("Start to test TiFlash autoscale")
	tidbClient := NewTidbClient(config.TidbAddr, config.TidbUser, config.TidbPassword, config.DbName)
	//tiDBClient.Init()
	//defer tiDBClient.Close()
	if config.NeedLoadData {
		out, err := tidbClient.LoadData(config.LoadScale, config.LoadTable)
		if err != nil {
			log.Fatalf("[Error]LoadData failed: %v, %s", err, out)
		}
		log.Printf("LoadData: %s", out)
	}
	tidbClient.Init()
	defer tidbClient.Close()
	tidbClient.SetTiFlashReplica()
	start := time.Now()
	for {
		if time.Since(start) > time.Duration(config.CheckTimeout)*time.Second {
			log.Fatal("[Error]CheckTiFlashReady timeout")
		}
		InformationSchemaRows := tidbClient.GetTiFlashInformationSchema()
		if CheckTiFlashReady(InformationSchemaRows) {
			break
		}
		time.Sleep(time.Duration(config.CheckInterval) * time.Second)
	}
	log.Println("TiFlash is ready, begin to run bench")
	queryCount := 1000
	threadNum := 2
	log.Printf("[Round1]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	out, err := tidbClient.RunBench(queryCount, threadNum)
	if err != nil {
		log.Fatalf("[Error][Round1]RunBench failed: %v, %s", err, out)
	}
	log.Printf("[Round1]RunBench: %s", out)

}
