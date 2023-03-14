package main

type TidbClient struct {
	tidbAddr string
}

func NewTidbClient(tidbAddr string) *TidbClient {
	return &TidbClient{tidbAddr: tidbAddr}
}
