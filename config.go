package main

import "strings"

const (
	DefaultAutoscaleHttpServerAddr = "tiflash-autoscale-lb.tiflash-autoscale.svc.cluster.local:8081"
	DefaultTidbAddr                = "127.0.0.1:4000"
	DefaultTidbUser                = "root"
	DefaultTidbPassword            = ""
	DefaultNeedLoadData            = true
	DefaultLoadScale               = "0.1"
	DefaultLoadTable               = "all"
	DefaultCheckInterval           = 10
	DefaultCheckTimeout            = 120
	DefaultEnableAutoScale         = true
	DefaultTidbClusterID           = "t1"
)

type Config struct {
	AutoscaleHttpServerAddr string
	TidbAddr                string
	TidbUser                string
	TidbPassword            string
	NeedLoadData            bool
	LoadScale               string
	LoadTable               string
	CheckInterval           int
	CheckTimeout            int
	DbName                  string
	EnableAutoScale         bool
	TidbClusterID           string
}

func NewConfig(autoscaleHttpServerAddr string, tidbAddr string, tidbUser string, tidbPassword string, needLoadData bool, loadScale string, loadTable string, checkInterval int, checkTimeout int, enableAutoScale bool, tidbClusterID string) *Config {
	config := &Config{
		AutoscaleHttpServerAddr: autoscaleHttpServerAddr,
		TidbAddr:                tidbAddr,
		TidbUser:                tidbUser,
		TidbPassword:            tidbPassword,
		NeedLoadData:            needLoadData,
		LoadScale:               loadScale,
		LoadTable:               loadTable,
		CheckInterval:           checkInterval,
		CheckTimeout:            checkTimeout,
		EnableAutoScale:         enableAutoScale,
		TidbClusterID:           tidbClusterID,
	}
	config.DbName = getDefaultDbName(config.LoadScale)
	return config
}

func NewDefaultConfig() *Config {
	return NewConfig(DefaultAutoscaleHttpServerAddr, DefaultTidbAddr, DefaultTidbUser, DefaultTidbPassword, DefaultNeedLoadData, DefaultLoadScale, DefaultLoadTable, DefaultCheckInterval, DefaultCheckTimeout, DefaultEnableAutoScale, DefaultTidbClusterID)
}

func getDefaultDbName(loadScale string) string {
	return "tpch_" + strings.ReplaceAll(loadScale, ".", "_")
}
