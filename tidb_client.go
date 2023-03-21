package main

import (
	"database/sql"
	"fmt"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"log"
	"os/exec"
)

type TidbClient struct {
	tidbAddr     string
	tidbUser     string
	tidbPassword string
	db           *sql.DB
}

func NewTidbClient(tidbAddr string, tidbUser string, tidbPassword string) *TidbClient {
	tidbClient := &TidbClient{tidbAddr: tidbAddr, tidbUser: tidbUser, tidbPassword: tidbPassword}
	return tidbClient
}

func (c *TidbClient) Init() {
	dsn := fmt.Sprintf("root:@tcp(%s)/tpch_0_1?charset=utf8mb4", c.tidbAddr)
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

func (c *TidbClient) LoadData(loadScale float32, loadTable string) (string, error) {
	host, port := ConvertTidbAddrToHostAndPort(c.tidbAddr)
	var passwordOption string
	if c.tidbPassword == "" {
		passwordOption = ""
	} else {
		passwordOption = "-p" + c.tidbPassword
	}
	cmd := exec.Command("/bin/bash", "./scripts/rep-and-gendb.sh", c.tidbUser, passwordOption, host, port)
	out, err := cmd.Output()
	if err != nil {
		return string(out), err
	}
	cmd = exec.Command("/bin/bash", "./integrated/tools/tpch_load.sh", host, port, fmt.Sprintf("%f", loadScale), loadTable)
	out, err = cmd.Output()
	return string(out), err
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

// GetTiFlashStatus TODO
func (c *TidbClient) GetTiFlashStatus() bool {
	rows, err := c.db.Query("select * from information_schema.tiflash_replica;")
	if err != nil {
		log.Fatal("Query error: ", err)
	}
	defer rows.Close()
	return rows.Next()
}

func MustExec(DB *sql.DB, query string, args ...interface{}) sql.Result {
	r, err := DB.Exec(query, args...)
	if err != nil {
		log.Fatal("Exec query error: ", err)
	}
	return r
}
