package main

import (
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
		out, err := tidbClient.LoadData(config.LoadScale, config.LoadTable)
		if err != nil {
			log.Panicf("[Error][TidbClient]LoadData failed: %s, %s", err, out)
		}
	}
}
