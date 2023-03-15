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
	tidbClient      *TiDBClient
}

func NewClientManger(autoscaleClient *AutoscaleClient, tidbClient *TiDBClient) *ClientManger {
	return &ClientManger{autoscaleClient: autoscaleClient, tidbClient: tidbClient}
}
