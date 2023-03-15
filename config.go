package main

const (
	DefaultAutoscaleHttpServerAddr = "tiflash-autoscale-lb.tiflash-autoscale.svc.cluster.local:8081"
	DefaultTidbAddr                = "127.0.0.1:4000"
	DefaultTidbUser                = "root"
	DefaultTidbPassword            = ""
	DefaultNeedLoadData            = true
)

type Config struct {
	AutoscaleHttpServerAddr string
	TidbAddr                string
	TidbUser                string
	TidbPassword            string
	NeedLoadData            bool
}

func NewConfig(autoscaleHttpServerAddr string, tidbAddr string, tidbUser string, tidbPassword string, needLoadData bool) *Config {
	return &Config{
		AutoscaleHttpServerAddr: autoscaleHttpServerAddr,
		TidbAddr:                tidbAddr,
		TidbUser:                tidbUser,
		TidbPassword:            tidbPassword,
		NeedLoadData:            needLoadData,
	}
}

func NewDefaultConfig() *Config {
	return NewConfig(DefaultAutoscaleHttpServerAddr, DefaultTidbAddr, DefaultTidbUser, DefaultTidbPassword, DefaultNeedLoadData)
}
