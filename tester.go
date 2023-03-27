package main

type ClientManger struct {
	autoscaleClient *AutoscaleClient
	tidbClient      *TidbClient
}

func NewClientManger(autoscaleClient *AutoscaleClient, tidbClient *TidbClient) *ClientManger {
	return &ClientManger{autoscaleClient: autoscaleClient, tidbClient: tidbClient}
}
