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
	log.Printf("[config]AutoscaleHttpServerAddr: %s", config.AutoscaleHttpServerAddr)
	log.Printf("[config]TidbAddr: %s", config.TidbAddr)
	log.Printf("[config]TidbUser: %s", config.TidbUser)
	log.Printf("[config]NeedLoadData: %v", config.NeedLoadData)
	log.Printf("[config]LoadScale: %s", config.LoadScale)
	log.Printf("[config]LoadTable: %s", config.LoadTable)
	log.Printf("[config]CheckInterval: %d", config.CheckInterval)
	log.Printf("[config]CheckTimeout: %d", config.CheckTimeout)
	log.Printf("[config]EnableAutoScale: %v", config.EnableAutoScale)
	log.Printf("[config]TidbClusterID: %s", config.TidbClusterID)
	log.Printf("[config]DbName: %s", config.DbName)
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
	queryCount := config.Workload.Round1.QueryCount
	threadNum := config.Workload.Round1.ThreadNum
	log.Printf("[Round1]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	round1Start := time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	round1End := time.Now()
	if err != nil {
		log.Fatalf("[Error][Round1]RunBench failed: %v", err)
	}
	log.Printf("[Round1]RunBench end, cost time: %v", round1End.Sub(round1Start).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[Round1]state: %s, topo: %v", state, topo)
	}
	queryCount = config.Workload.Round2.QueryCount
	threadNum = config.Workload.Round2.ThreadNum
	log.Printf("[Round2]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	round2Start := time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	round2End := time.Now()
	if err != nil {
		log.Fatalf("[Error][Round2]RunBench failed: %v", err)
	}
	log.Printf("[Round2]RunBench end, cost time: %v", round2End.Sub(round2Start).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 2, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[Round2]state: %s, topo: %v", state, topo)
	}
	queryCount = config.Workload.Round3.QueryCount
	threadNum = config.Workload.Round3.ThreadNum
	log.Printf("[Round3]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	round3Start := time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	round3End := time.Now()
	if err != nil {
		log.Fatalf("[Error][Round3]RunBench failed: %v", err)
	}
	log.Printf("[Round3]RunBench end, cost time: %v", round3End.Sub(round3Start).Minutes())
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
