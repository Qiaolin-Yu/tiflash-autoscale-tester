package main

import (
	"github.com/stretchr/testify/assert"
	"log"
	"testing"
)

func TestAutoscale(t *testing.T) {
	config := NewDefaultConfig()
	log.Println("Start to test TiFlash autoscale")
	tiDBClient := NewTidbClient(config.TidbAddr)
	//tiDBClient.Init()
	//defer tiDBClient.Close()
	if config.NeedLoadData {
		err := tiDBClient.LoadData()
		assert.NoError(t, err)
	}
}
