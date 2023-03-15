package main

const (
	TenantStateResumedString  = "resumed"
	TenantStateResumingString = "resuming"
	TenantStatePausedString   = "paused"
	TenantStatePausingString  = "pausing"
	TenantStateUnknownString  = "unknown"
)

type ClientManger struct {
	autoscaleClient *AutoscaleClient
	tidbClient      *TidbClient
}

func NewClientManger(autoscaleClient *AutoscaleClient, tidbClient *TidbClient) *ClientManger {
	return &ClientManger{autoscaleClient: autoscaleClient, tidbClient: tidbClient}
}
