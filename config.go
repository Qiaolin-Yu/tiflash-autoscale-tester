package main

import (
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	DefaultAutoscaleHttpServerAddr = "http://tiflash-autoscale-lb.tiflash-autoscale.svc.cluster.local:8081"
	DefaultTidbAddr                = "127.0.0.1:4000"
	DefaultTidbUser                = "root"
	DefaultTidbPassword            = ""
	DefaultNeedLoadData            = false
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
	Workload                WorkloadConfig
}

type WorkloadConfig struct {
	Round1 struct {
		QueryCount int `yaml:"queryCount"`
		ThreadNum  int `yaml:"threadNum"`
	} `yaml:"round1"`
	Round2 struct {
		QueryCount int `yaml:"queryCount"`
		ThreadNum  int `yaml:"threadNum"`
	} `yaml:"round2"`
	Round3 struct {
		QueryCount int `yaml:"queryCount"`
		ThreadNum  int `yaml:"threadNum"`
	} `yaml:"round3"`
}

func ReadConfigFromYAMLFile(filename string) (*Config, error) {
	yamlData, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var yamlConfig struct {
		Tidb struct {
			Addr     string `yaml:"addr"`
			User     string `yaml:"user"`
			Password string `yaml:"password"`
		} `yaml:"tidb"`
		Load struct {
			NeedLoadData bool   `yaml:"needLoadData"`
			Scale        string `yaml:"scale"`
			Table        string `yaml:"table"`
		} `yaml:"load"`
		Check struct {
			Interval int `yaml:"interval"`
			Timeout  int `yaml:"timeout"`
		} `yaml:"check"`
		Autoscale struct {
			EnableAutoScale bool   `yaml:"enableAutoScale"`
			TidbClusterID   string `yaml:"tidbClusterID"`
			HttpServerAddr  string `yaml:"httpServerAddr"`
		} `yaml:"autoscale"`
		Workload WorkloadConfig `yaml:"workload"`
	}

	if err := yaml.Unmarshal(yamlData, &yamlConfig); err != nil {
		return nil, err
	}

	config := NewDefaultConfig()

	config.NeedLoadData = yamlConfig.Load.NeedLoadData

	config.EnableAutoScale = yamlConfig.Autoscale.EnableAutoScale

	config.Workload = yamlConfig.Workload

	if yamlConfig.Tidb.Addr != "" {
		config.TidbAddr = yamlConfig.Tidb.Addr
	}
	if yamlConfig.Tidb.User != "" {
		config.TidbUser = yamlConfig.Tidb.User
	}
	if yamlConfig.Tidb.Password != "" {
		config.TidbPassword = yamlConfig.Tidb.Password
	}

	if yamlConfig.Load.Scale != "" {
		config.LoadScale = yamlConfig.Load.Scale
		config.DbName = getDefaultDbName(config.LoadScale)
	}
	if yamlConfig.Load.Table != "" {
		config.LoadTable = yamlConfig.Load.Table
	}

	if yamlConfig.Check.Interval != 0 {
		config.CheckInterval = yamlConfig.Check.Interval
	}
	if yamlConfig.Check.Timeout != 0 {
		config.CheckTimeout = yamlConfig.Check.Timeout
	}

	if yamlConfig.Autoscale.TidbClusterID != "" {
		config.TidbClusterID = yamlConfig.Autoscale.TidbClusterID
	}
	if yamlConfig.Autoscale.HttpServerAddr != "" {
		config.AutoscaleHttpServerAddr = yamlConfig.Autoscale.HttpServerAddr
	}

	return config, nil
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
