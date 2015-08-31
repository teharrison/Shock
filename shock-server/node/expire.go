package node

import (
	"github.com/MG-RAST/Shock/shock-server/logger"
	"github.com/MG-RAST/golib/mgo/bson"
	"time"
)

type NodeReaper struct{}

func NewNodeReaper() *NodeReaper {
	return &NodeReaper{}
}

func (nr *NodeReaper) Handle() {
	for {
		// sleep
		time.Sleep(10 * time.Second)
		// query to get expired nodes
		nodes := Nodes{}
		query := nr.getQuery()
		nodes.GetAll(query)
		// delete expired nodes
		for _, n := range nodes {
			if err := n.Delete(); err != nil {
				err_msg := "err:@node_delete: " + err.Error()
				logger.Error(err_msg)
			}
		}
	}
}

func (nr *NodeReaper) getQuery() (query bson.M) {
	hasExpire := bson.M{"expiration": bson.M{"$exists": true}}   // has the field
	toExpire := bson.M{"expiration": bson.M{"$ne": time.Time{}}} // value has been set, not default
	isExpired := bson.M{"expiration": bson.M{"$gt": time.Now()}} // value is too old
	query = bson.M{"$and": []bson.M{hasExpire, toExpire, isExpired}}
	return
}