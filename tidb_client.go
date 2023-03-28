package main

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"strings"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type TidbClient struct {
	tidbAddr     string
	tidbUser     string
	tidbPassword string
	dbName       string
	db           *sql.DB
}

type InformationSchema struct {
	TableSchema    string
	TableName      string
	TableId        string
	ReplicaCount   int
	LocationLabels string
	Available      float64
	Progress       float64
}

func NewTidbClient(tidbAddr string, tidbUser string, tidbPassword string, dbName string) *TidbClient {
	tidbClient := &TidbClient{tidbAddr: tidbAddr, tidbUser: tidbUser, tidbPassword: tidbPassword, dbName: dbName}
	return tidbClient
}

func (c *TidbClient) Init() {
	dsn := fmt.Sprintf(c.tidbUser+":@tcp(%s)/"+c.dbName+"?charset=utf8mb4", c.tidbAddr)
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		panic(err)
	}
	log.Printf("[TidbClient]Connected to %s", c.tidbAddr)
	tidb, err := db.DB()
	if err != nil {
		panic(err)
	}
	c.db = tidb
}

func (c *TidbClient) Close() {
	c.db.Close()
}

func (c *TidbClient) LoadData(loadScale string, loadTable string) error {
	host, port := ConvertTidbAddrToHostAndPort(c.tidbAddr)
	var passwordOption string
	if c.tidbPassword == "" {
		passwordOption = ""
	} else {
		passwordOption = "-p" + c.tidbPassword
	}
	outStr, errStr, err := RunCommand("/bin/bash", "./scripts/rep-conf.sh", c.tidbUser, passwordOption, host, port)
	log.Printf("[rep-conf] %s", outStr)
	if errStr != "" {
		log.Printf("[error][rep-conf]: %s", errStr)
	}
	if err != nil {
		return err
	}
	outStr, errStr, err = RunCommand("/bin/bash", "./integrated/tools/tpch_load.sh", host, port, loadScale, loadTable)
	log.Printf("[tpch_load] %s", outStr)
	if errStr != "" {
		log.Printf("[error][tpch_load]: %s", errStr)
	}
	return err
}

func (c *TidbClient) RunBench(queryCount int, threadNum int) error {
	outStr, errStr, err := RunCommand("tiup", "bench", "rawsql", "run", "--count", fmt.Sprintf("%d", queryCount), "--query-files", "sql/hehe.sql", "--db", c.dbName, "--threads", fmt.Sprintf("%d", threadNum))
	log.Printf("[tiup bench] %s", outStr)
	if errStr != "" {
		log.Printf("[error][tiup bench]: %s", errStr)
		if strings.Contains(errStr, "DB::Exception") && err == nil {
			return errors.New("tiup bench query error")
		}
	}
	return err

}

func (c *TidbClient) SetTiFlashReplica() {
	log.Printf("[TidbClient]Set TiFlash replica")
	MustExec(c.db, "ALTER TABLE nation SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE region SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE customer SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE supplier SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE partsupp SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE lineitem SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE orders SET TIFLASH REPLICA 1;")
	MustExec(c.db, "ALTER TABLE part SET TIFLASH REPLICA 1;")
}

func (c *TidbClient) GetTiFlashInformationSchema() []InformationSchema {
	rows, err := c.db.Query("select * from information_schema.tiflash_replica;")
	if err != nil {
		log.Fatal("Query error: ", err)
	}
	var rowsInfo []InformationSchema
	var row InformationSchema
	defer rows.Close()
	for rows.Next() {
		err := rows.Scan(&row.TableSchema, &row.TableName, &row.TableId, &row.ReplicaCount, &row.LocationLabels, &row.Available, &row.Progress)
		if err != nil {
			log.Fatal(err)
		}
		rowsInfo = append(rowsInfo, row)
	}
	err = rows.Err()
	if err != nil {
		log.Fatal(err)
	}
	return rowsInfo
}

func CheckTiFlashReady(schemaRows []InformationSchema) bool {
	for _, row := range schemaRows {
		if row.Available <= 1 {
			return false
		}
	}
	return true
}

func MustExec(DB *sql.DB, query string, args ...interface{}) sql.Result {
	r, err := DB.Exec(query, args...)
	if err != nil {
		log.Fatal("Exec query error: ", err)
	}
	return r
}
