package main

const (
	DefaultAutoscaleHttpServerAddr = "tiflash-autoscale-lb.tiflash-autoscale.svc.cluster.local:8081"
	DefaultTidbAddr                = "127.0.0.1:4000"
	DefaultNeedLoadData            = true
)

type Config struct {
	AutoscaleHttpServerAddr string
	TidbAddr                string
	NeedLoadData            bool
}

func NewConfig(autoscaleHttpServerAddr string, tidbAddr string, needLoadData bool) *Config {
	return &Config{
		AutoscaleHttpServerAddr: autoscaleHttpServerAddr,
		TidbAddr:                tidbAddr,
		NeedLoadData:            needLoadData,
	}
}

func NewDefaultConfig() *Config {
	return NewConfig(DefaultAutoscaleHttpServerAddr, DefaultTidbAddr, DefaultNeedLoadData)
}
