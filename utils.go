package main

import "strings"

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
