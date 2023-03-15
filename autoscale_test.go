package main

import (
	"github.com/stretchr/testify/assert"
	"log"
	"testing"
)

func TestAutoscale(t *testing.T) {
	config := NewDefaultConfig()
	log.Println("Start to test TiFlash autoscale")
	tidbClient := NewTidbClient(config.TidbAddr, config.TidbUser, config.TidbPassword)
	//tiDBClient.Init()
	//defer tiDBClient.Close()
	if config.NeedLoadData {
		err := tidbClient.LoadData()
		assert.NoError(t, err)
	}
}
