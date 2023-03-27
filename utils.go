package main

import (
	"bytes"
	"os/exec"
	"strings"
)

func ConvertInterfaceToStringSlice(data interface{}) []string {
	var res []string
	for _, v := range data.([]interface{}) {
		res = append(res, v.(string))
	}
	return res
}

func ConvertTidbAddrToHostAndPort(tidbAddr string) (string, string) {
	host := tidbAddr[:strings.Index(tidbAddr, ":")]
	port := tidbAddr[strings.Index(tidbAddr, ":")+1:]
	return host, port
}

func RunCommand(command string, args ...string) (string, string, error) {
	cmd := exec.Command(command, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	outStr, errStr := string(stdout.Bytes()), string(stderr.Bytes())
	return outStr, errStr, err
}
