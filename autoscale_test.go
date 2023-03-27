package main

import (
	"github.com/stretchr/testify/assert"
	"log"
	"testing"
	"time"
)

func TestAutoscale(t *testing.T) {
	config, err := ReadConfigFromYAMLFile("config.yaml")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("AutoscaleHttpServerAddr: %s", config.AutoscaleHttpServerAddr)
	log.Printf("TidbAddr: %s", config.TidbAddr)
	log.Printf("TidbUser: %s", config.TidbUser)
	log.Printf("NeedLoadData: %v", config.NeedLoadData)
	log.Printf("LoadScale: %s", config.LoadScale)
	log.Printf("LoadTable: %s", config.LoadTable)
	log.Printf("CheckInterval: %d", config.CheckInterval)
	log.Printf("CheckTimeout: %d", config.CheckTimeout)
	log.Printf("EnableAutoScale: %v", config.EnableAutoScale)
	log.Printf("TidbClusterID: %s", config.TidbClusterID)
	log.Println("Start to test TiFlash autoscale")

	tidbClient := NewTidbClient(config.TidbAddr, config.TidbUser, config.TidbPassword, config.DbName)
	var autoscaleClient *AutoscaleClient
	if config.EnableAutoScale {
		autoscaleClient = NewAutoscaleClient(config.AutoscaleHttpServerAddr)
	}
	if config.NeedLoadData {
		err := tidbClient.LoadData(config.LoadScale, config.LoadTable)
		if err != nil {
			log.Fatalf("[Error]LoadData failed: %v", err)
		}
		log.Printf("LoadData end")
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
	queryCount := 500
	threadNum := 2
	log.Printf("[Round1]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	err = tidbClient.RunBench(queryCount, threadNum)
	if err != nil {
		log.Fatalf("[Error][Round1]RunBench failed: %v", err)
	}
	log.Printf("[Round1]RunBench end")
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[Round1]state: %s, topo: %v", state, topo)
	}
	queryCount = 5000
	threadNum = 50
	log.Printf("[Round2]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	err = tidbClient.RunBench(queryCount, threadNum)
	if err != nil {
		log.Fatalf("[Error][Round2]RunBench failed: %v", err)
	}
	log.Printf("[Round2]RunBench end")
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 2, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[Round2]state: %s, topo: %v", state, topo)
	}
	queryCount = 500
	threadNum = 2
	log.Printf("[Round3]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	err = tidbClient.RunBench(queryCount, threadNum)
	if err != nil {
		log.Fatalf("[Error][Round3]RunBench failed: %v", err)
	}
	log.Printf("[Round3]RunBench end")
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[Round3]state: %s, topo: %v", state, topo)
	}
}
