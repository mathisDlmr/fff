import pymongo
import time
import sys
import os

myclient = pymongo.MongoClient(f"mongodb://{ os.environ['MONGO_HOST'] }:27017/")
mydb = myclient['pritunl']

#
# this is the MongoDB version of doing a join on two tables...
# while we only pull out the fields we care about.
#
pipeline =  [{'$lookup': 
   {'from' : 'users',
    'localField' : 'user_id',
    'foreignField' : '_id',
    'as' : 'userinfo'}},
    {
       "$project" :{
          "real_address" :1, "connected_since": 1, "virt_address" : 1, "mac_addr" :1, "user_id" :1 ,
          "username" : "$userinfo.name"
       }
    }
   ]

previousclients = []
while True:

   currentclients = list(mydb.clients.aggregate(pipeline))

   if previousclients != currentclients:
      if previousclients == []:
         print(f"{time.asctime( time.localtime(time.time()))} starting logger, clients connected now are:")
      else:
         for client in currentclients:
            if not client in previousclients:
               timeconnected = time.asctime(time.localtime(client['connected_since'] - time.timezone))
               print("connected  %-17s real_address %-15s virt_address %-19s connected_since %s mac_addr %s" % \
                     (client['username'][0],client['real_address'],client['virt_address'],timeconnected,client['mac_addr']))
         for client in previousclients:
            if not client in currentclients:
               timeconnected = time.asctime(time.localtime(client['connected_since'] - time.timezone))
               print("disconnect %-17s real_address %-15s virt_address %-19s connected_since %s mac_addr %s" % \
                     (client['username'][0],client['real_address'],client['virt_address'],timeconnected,client['mac_addr']))
         sys.stdout.flush()

   previousclients = currentclients
   time.sleep(1.0)
