package main

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
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

func (c *AutoscaleClient) ResumeAndGetTopology(tidbClusterID string) (string, []string, error) {
	resumeAndGetTopologyResp, err := http.PostForm(c.httpServerAddr+"/resume-and-get-topology", url.Values{
		"tidbclusterid": {tidbClusterID},
	})
	if err != nil {
		return "", nil, err
	}
	defer resumeAndGetTopologyResp.Body.Close()
	if resumeAndGetTopologyResp.StatusCode != http.StatusOK {
		return "", nil, errors.New("resume-and-get-topology failed")
	}
	data, err := io.ReadAll(resumeAndGetTopologyResp.Body)
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
	return res["topology"].(string), ConvertInterfaceToStringSlice(res["rns"]), nil
}
