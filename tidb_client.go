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
	return &TidbClient{tidbAddr: tidbAddr, tidbUser: tidbUser, tidbPassword: tidbPassword}
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

// LoadData TODO
func (c *TidbClient) LoadData() error {
	host, port := ConvertTidbAddrToHostAndPort(c.tidbAddr)
	var password string
	if c.tidbPassword == "" {
		password = ""
	} else {
		password = "-p" + c.tidbPassword
	}
	cmd := exec.Command("/bin/sh", "./scripts/rep-and-gendb.sh", c.tidbUser, password, host, port)
	err := cmd.Run()
	if err != nil {
		return err
	}
	return nil
}

// GetTiFlashStatus TODO
func (c *TidbClient) GetTiFlashStatus() error {
	return nil
}
