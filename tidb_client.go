package main

import (
	"fmt"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"log"
	"os/exec"
)

type TiDBClient struct {
	tidbAddr string
	db       *gorm.DB
}

func NewTidbClient(tidbAddr string) *TiDBClient {
	return &TiDBClient{
		tidbAddr: tidbAddr,
	}
}

func (c *TiDBClient) Init() {
	dsn := fmt.Sprintf("root:@tcp(%s)/tpch_0_1?charset=utf8mb4", c.tidbAddr)
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		panic(err)
	}
	log.Printf("[TiDBClient]Connected to %s", c.tidbAddr)
	c.db = db
}

func (c *TiDBClient) Close() {
	sqlDB, err := c.db.DB()
	if err != nil {
		panic(err)
	}
	sqlDB.Close()
}

// LoadData TODO
func (c *TiDBClient) LoadData() error {
	host, port := ConvertTidbAddrToHostAndPort(c.tidbAddr)
	cmd := exec.Command("/bin/sh", "./scripts/rep-and-gendb.sh", "root", "", host, port)
	err := cmd.Run()
	if err != nil {
		return err
	}
	return nil
}

// GetTiFlashStatus TODO
func (c *TiDBClient) GetTiFlashStatus() error {
	return nil
}
