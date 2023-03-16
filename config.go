package main

const (
	DefaultAutoscaleHttpServerAddr = "tiflash-autoscale-lb.tiflash-autoscale.svc.cluster.local:8081"
	DefaultTidbAddr                = "127.0.0.1:4000"
	DefaultTidbUser                = "root"
	DefaultTidbPassword            = ""
	DefaultNeedLoadData            = true
	DefaultLoadScale               = 0.1
	DefaultLoadTable               = "all"
)

type Config struct {
	AutoscaleHttpServerAddr string
	TidbAddr                string
	TidbUser                string
	TidbPassword            string
	NeedLoadData            bool
	LoadScale               float32
	LoadTable               string
}

func NewConfig(autoscaleHttpServerAddr string, tidbAddr string, tidbUser string, tidbPassword string, needLoadData bool, loadScale float32, loadTable string) *Config {
	return &Config{
		AutoscaleHttpServerAddr: autoscaleHttpServerAddr,
		TidbAddr:                tidbAddr,
		TidbUser:                tidbUser,
		TidbPassword:            tidbPassword,
		NeedLoadData:            needLoadData,
		LoadScale:               loadScale,
		LoadTable:               loadTable,
	}
}

func NewDefaultConfig() *Config {
	return NewConfig(DefaultAutoscaleHttpServerAddr, DefaultTidbAddr, DefaultTidbUser, DefaultTidbPassword, DefaultNeedLoadData, DefaultLoadScale, DefaultLoadTable)
}
