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
	queryCount := config.Workload.PauseResumeTest.QueryCount
	threadNum := config.Workload.PauseResumeTest.ThreadNum
	log.Printf("[PauseResumeTest][Round1]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	pauseResumeTestStart := time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	pauseResumeTestEnd := time.Now()
	if err != nil {
		log.Fatalf("[Error][PauseResumeTest][Round1]RunBench failed: %v", err)
	}
	log.Printf("[PauseResumeTest][Round1]RunBench end, run for %v minutes", pauseResumeTestEnd.Sub(pauseResumeTestStart).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[PauseResumeTest][Round1]state: %s, topo: %v", state, topo)
	}
	log.Printf("[PauseResumeTest]stop benchmark, wait for pause")
	time.Sleep(2 * time.Minute)
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStatePausedString, state)
		assert.Equal(t, 0, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[PauseResumeTest][Pause]state: %s, topo: %v", state, topo)
	}

	queryCount = config.Workload.PauseResumeTest.QueryCount
	threadNum = config.Workload.PauseResumeTest.ThreadNum
	log.Printf("[PauseResumeTest][Round2]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	pauseResumeTestStart = time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	pauseResumeTestEnd = time.Now()
	if err != nil {
		log.Fatalf("[Error][PauseResumeTest][Round2]RunBench failed: %v", err)
	}
	log.Printf("[PauseResumeTest][Round2]RunBench end, run for %v minutes", pauseResumeTestEnd.Sub(pauseResumeTestStart).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[PauseResumeTest][Round2]state: %s, topo: %v", state, topo)
	}

	queryCount = config.Workload.ScaleOutTest.QueryCount
	threadNum = config.Workload.ScaleOutTest.ThreadNum
	log.Printf("[ScaleOutTest]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	scaleOutTestStart := time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	scaleOutTestEnd := time.Now()
	if err != nil {
		log.Fatalf("[Error][ScaleOutTest]RunBench failed: %v", err)
	}
	log.Printf("[ScaleOutTest]RunBench end, run for %v minutes", scaleOutTestEnd.Sub(scaleOutTestStart).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 2, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[ScaleOutTest]state: %s, topo: %v", state, topo)
	}
	queryCount = config.Workload.ScaleInTest.QueryCount
	threadNum = config.Workload.ScaleInTest.ThreadNum
	log.Printf("[ScaleInTest]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	scaleInTestStart := time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	scaleInTestEnd := time.Now()
	if err != nil {
		log.Fatalf("[Error][ScaleInTest]RunBench failed: %v", err)
	}
	log.Printf("[ScaleInTest]RunBench end, run for %v minutes", scaleInTestEnd.Sub(scaleInTestStart).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[ScaleInTest]state: %s, topo: %v", state, topo)
	}

	queryCount = config.Workload.ScaleOutTest.QueryCount
	threadNum = config.Workload.ScaleOutTest.ThreadNum
	log.Printf("[ScaleOutTest]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	scaleOutTestStart = time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	scaleOutTestEnd = time.Now()
	if err != nil {
		log.Fatalf("[Error][ScaleOutTest]RunBench failed: %v", err)
	}
	log.Printf("[ScaleOutTest]RunBench end, run for %v minutes", scaleOutTestEnd.Sub(scaleOutTestStart).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 2, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[ScaleOutTest]state: %s, topo: %v", state, topo)
	}

	queryCount = config.Workload.ScaleInTest.QueryCount
	threadNum = config.Workload.ScaleInTest.ThreadNum
	log.Printf("[ScaleInTest]RunBenchmark: queryCount=%d, threadNum=%d", queryCount, threadNum)
	scaleInTestStart = time.Now()
	err = tidbClient.RunBench(queryCount, threadNum)
	scaleInTestEnd = time.Now()
	if err != nil {
		log.Fatalf("[Error][ScaleInTest]RunBench failed: %v", err)
	}
	log.Printf("[ScaleInTest]RunBench end, run for %v minutes", scaleInTestEnd.Sub(scaleInTestStart).Minutes())
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStateResumedString, state)
		assert.Equal(t, 1, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[ScaleInTest]state: %s, topo: %v", state, topo)
	}

	time.Sleep(2 * time.Minute)
	if config.EnableAutoScale {
		state, numOfRNs, err := autoscaleClient.GetState(config.TidbClusterID)
		assert.NoError(t, err)
		assert.Equal(t, TenantStatePausedString, state)
		assert.Equal(t, 0, numOfRNs)
		state, topo, err := autoscaleClient.GetTopology(config.TidbClusterID)
		assert.NoError(t, err)
		log.Printf("[TestEnd][Pause]state: %s, topo: %v", state, topo)
	}
}
