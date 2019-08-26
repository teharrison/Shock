package cache

import (
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strings"
	"time"

	"github.com/MG-RAST/Shock/shock-server/conf"
	"github.com/MG-RAST/Shock/shock-server/logger"
	// remove for production :-)
)

// Item information to manage file expiration on cache servers
type Item struct {
	UUID      string    `bson:"uuid" json:"uuid" `                   // e.g. node UUID
	Access    time.Time `bson:"last_accessed" json:"last_accessed" ` // e.g. access time
	Type      string    `bson:"type" json:"type"`
	Size      int64     `bson:"size" json:"size"  `        // e.g. size in bytes
	CreatedOn time.Time `bson:"url" json:"url" yaml:"URL"` // e.g. creation of local copy
}

// CacheMap store UUID, size, type, atime and ctime in separate (sorted) table for access by fileReaper
var CacheMap map[string]*Item

// Path2uuid extract uuid from path
func path2uuid(fpath string) string {

	ext := path.Ext(fpath)                     // identify extension
	filename := strings.TrimSuffix(fpath, ext) // find filename
	uuid := path.Base(filename)                // implement basename cmd

	return uuid
}

// Initialize find all *.data files for nodes and populate cache
// only call if global --is-cache=true
func Initialize() (err error) {

	if conf.PATH_CACHE == "" { // no PATH_CACHE set will stop
		logger.Info(fmt.Sprintf("(cache) not initializing; not configured)\n "))
		return
	}

	//logger.Info(fmt.Sprintf("(cache) initializing: %s)\n ", DataRoot))
	//
	Pattern := fmt.Sprintf("%s/*/*/*/*/*.data", conf.PATH_CACHE)

	//debug
	logger.Info(fmt.Sprintf("(cache->Initialize) listing files for Pattern: %s\n ", Pattern))

	nodefiles, err := filepath.Glob(Pattern)

	if err != nil {
		logger.Error(fmt.Sprintf("(cache->Initialize) error reading %s (Error:%s)", Pattern, err.Error()))
		return
	}
	CacheMap = make(map[string]*Item)

	for _, file := range nodefiles {

		//		fmt.Printf("(cache->Initialize) file %s \n", file)

		var fileinfo os.FileInfo
		fileinfo, err = os.Stat(file)

		if err != nil {
			logger.Error(fmt.Sprintf("(cache->Initialize) error reading %s (Error:%s)", file, err.Error()))
			continue
		}
		filename := path2uuid(file)

		var entry Item

		entry.UUID = filename
		entry.Size = fileinfo.Size()
		entry.CreatedOn = fileinfo.ModTime()
		//Item.Access = ""
		now := time.Now()
		age := entry.CreatedOn
		diff := now.Sub(age)
		hours := diff.Hours()

		logger.Info(fmt.Sprintf("(cache->Initialize) added UUID %s, Size: %d, age(h): %f\n", entry.UUID, entry.Size, hours))

		// add the map bits
		CacheMap[entry.UUID] = &entry

	}
	return
}

// Add an entry to the Cache for ID
func Add(ID string, size int64) {

	var entry Item

	entry.UUID = ID
	entry.Size = size
	entry.CreatedOn = time.Now()

	CacheMap[entry.UUID] = &entry

	logger.Info(fmt.Sprintf("(Cache-->Add) added file: %s with size: %d\n ", ID, size))

	return
}

// Remove an entry to the CacheMap and the file on disk
func Remove(ID string) (err error) {

	//	var file os.File

	// return immediately if system is not setup to be cache
	if conf.PATH_CACHE == "" {
		return
	}

	// identify PATH to data
	// remove ..
	cachefile := fmt.Sprintf("%s/*/*/*/%s", conf.PATH_CACHE, ID) // the data file in cache
	itemfile := fmt.Sprintf("%s/*/*/*/%s", conf.PATH_DATA, ID)   // the symlink

	// uncomment to only remove data files
	//pattern := fmt.Sprintf("%s/*/*/*/%s/%s.data", DataRoot, ID, ID) // remove only data file

	cacheitempath, err := filepath.Glob(cachefile)
	//fmt.Println(itempath)
	if err != nil {
		logger.Info(fmt.Sprintf("(Cache-->Remove) removing %s --> %s from cache \n (%s)", cachefile, cacheitempath, err.Error()))
	}

	_, err = os.Stat(cacheitempath[0])
	if err == nil {
		logger.Info(fmt.Sprintf("(Cache-->Remove) removing %s from cache \n ", cacheitempath))
		os.RemoveAll(cacheitempath[0])
	} else {
		logger.Info(fmt.Sprintf("(Cache-->Remove) cannot remove %s from cache (%s)\n ", cacheitempath, err.Error()))
	}

	// remove object from Map and remove Cache Entry
	delete(CacheMap, ID)

	// remove link
	itempath, err := filepath.Glob(itemfile)
	//fmt.Println(itempath)
	if err != nil {
		logger.Info(fmt.Sprintf("(Cache-->Remove) removing %s --> %s from cache \n (%s)", cachefile, cacheitempath, err.Error()))
	}
	_, err = os.Stat(itempath[0])
	if err == nil {
		logger.Info(fmt.Sprintf("(Cache-->Remove) removing symlink for %s  \n ", itempath))
		os.RemoveAll(itempath[0])
	} else {
		logger.Info(fmt.Sprintf("(Cache-->Remove) cannot remove symlink %s (%s)\n ", cacheitempath, err.Error()))
	}

	return

}

// Touch update cache LRU info
func Touch(ID string) {

	//spew.Dump(CacheMap)

	CacheMap[ID].Access = time.Now()
	logger.Info(fmt.Sprintf("(Cache-->Touch) lru for  %s updated to %s\n ", ID, time.Now()))

}
