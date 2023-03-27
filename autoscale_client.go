package main

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
)

const (
	TenantStateResumedString  = "resumed"
	TenantStateResumingString = "resuming"
	TenantStatePausedString   = "paused"
	TenantStatePausingString  = "pausing"
	TenantStateUnknownString  = "unknown"
)

type AutoscaleClient struct {
	httpServerAddr string
}

func NewAutoscaleClient(httpServerAddr string) *AutoscaleClient {
	return &AutoscaleClient{httpServerAddr: httpServerAddr}
}

func (c *AutoscaleClient) GetState(tidbClusterID string) (string, int, error) {
	getStateResp, err := http.PostForm(c.httpServerAddr+"/getstate", url.Values{
		"tenantName": {tidbClusterID},
	})
	if err != nil {
		return "", 0, err
	}
	defer getStateResp.Body.Close()
	if getStateResp.StatusCode != http.StatusOK {
		return "", 0, errors.New("getstate failed")
	}
	data, err := io.ReadAll(getStateResp.Body)
	if err != nil {
		return "", 0, err
	}
	var res map[string]interface{}
	err = json.Unmarshal(data, &res)
	if err != nil {
		return "", 0, err
	}
	if res["hasError"].(float64) != 0.0 {
		return "", 0, errors.New(res["errorInfo"].(string))
	}
	return res["state"].(string), int(res["numOfRNs"].(float64)), nil
}

func (c *AutoscaleClient) GetTopology(tidbClusterID string) (string, []string, error) {
	getTopologyResp, err := http.PostForm(c.httpServerAddr+"/get-topology", url.Values{
		"tidbclusterid": {tidbClusterID},
	})
	if err != nil {
		return "", nil, err
	}
	defer getTopologyResp.Body.Close()
	if getTopologyResp.StatusCode != http.StatusOK {
		return "", nil, errors.New("get-topology failed")
	}
	data, err := io.ReadAll(getTopologyResp.Body)
	if err != nil {
		return "", nil, err
	}
	var res map[string]interface{}
	err = json.Unmarshal(data, &res)
	if err != nil {
		return "", nil, err
	}
	if res["hasError"].(float64) != 0.0 {
		return "", nil, errors.New(res["errorInfo"].(string))
	}
	return res["state"].(string), ConvertInterfaceToStringSlice(res["topology"]), nil
}
