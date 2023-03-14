package main

func ConvertInterfaceToStringSlice(data interface{}) []string {
	var res []string
	for _, v := range data.([]interface{}) {
		res = append(res, v.(string))
	}
	return res
}
