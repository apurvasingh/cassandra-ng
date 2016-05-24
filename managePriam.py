#!/usr/bin/env python

import sys
import os
import boto.sdb

# See http://boto.readthedocs.io/en/latest/simpledb_tut.html

class CmdLine:
    def __init__(self):
        self.region = 'us-east-1'
        self.key_id = 'AWS_KEY'
        self.secret_key = 'AWS_SECRET'
        self.domain = 'PriamProperties'
        self.prop = {}
        self.propName = None
        self.propKeys = [ 'appId', 'property', 'value' ]
        self.propNameKey = 'property'
        self.propToDelete = None
        self.bulkFile = None
        self.bulkPropertyList = []
        self.deleteBulk = False

    def processArgs(self,args):
        for arg in args:
            if (arg.startswith("--region=")):
                self.region = arg.split("=")[1]
            elif (arg.startswith("--domain=")):
                self.domain = arg.split("=")[1]
            elif (arg.startswith("--delete=")):
                self.propToDelete = arg.split("=")[1]
            elif (arg.startswith("--name=")):
                self.propName = arg.split("=")[1]
            elif (arg.startswith("--bulk=")):
                self.bulkFile = arg.split("=")[1]
            elif (arg.startswith("--deletebulk")):
                self.deleteBulk = True
            elif (arg == "-h") or (arg == "-?"):
                return False
            else:
                (propName, propValue) = arg.split("=")
                if not (propName in self.propKeys):
                    print "Warning: %s not in list of expected values: %s" % (propName, str(self.propKeys) )
                self.prop[propName] = propValue
                if (propName == self.propNameKey) and (self.propName == None):
                    self.propName = propValue
        return True

    def displayUsage(self,progName):
        print "Usage: %s [<flags> ...] [<name>=<value> [...]]" % progName
        print "Where <name> is the name of an attribute of this property, and <value> is the attribute's value"
        print "  Expected attributes are: %s" % str(self.propKeys)
        print "And <flags> can be zero or more of the following:"
        print "--region=<r>\t\tThe region where this SimpleDB is stored"
        print "--domain=<d>\t\tThe domain in which to store this property, default is %s" % self.domain
        print "--name=<n>\t\tOverride the name of the property item, defaults to value of '%s' attribute" % self.propNameKey
        print "--delete=<p>\t\tThe name of a property to delete"

def readBulkFile(filename):
    objList = []
    titles = None
    for line in open(filename,'r'):
        if (titles != None):
            obj = {}
            s = line.strip().split('\t')
            count = 0
            for field in titles:
                obj[field] = s[count]
                count += 1
                # print str(obj)
            objList.append(obj)
        elif (len(line) > 3):
            titles = line.strip().split('\t')
    return objList

def getItemNameFromObject(obj):
    key = ""
    if 'appId' in obj:
        key += obj['appId']
    if 'property' in obj:
        key += obj['property']
    return key

if __name__ == "__main__":
    cmd = CmdLine()
    if (not cmd.processArgs(sys.argv[1:])):
        cmd.displayUsage(os.path.basename(sys.argv[0]))
        sys.exit(1)

    print "Connecting to region %s ..." % cmd.region
    conn = boto.sdb.connect_to_region(cmd.region,
                                      aws_access_key_id=cmd.key_id,
                                      aws_secret_access_key=cmd.secret_key)
    if (conn == None):
        print "Unable to connect to region %s with key ID %s" % (cmd.region, cmd.key_id)
        sys.exit(1)

    domain = conn.get_domain(cmd.domain)
    if (domain == None):
        print "Error: domain %s not found" % cmd.domain
        sys.exit(1)

    if (cmd.propToDelete != None):
        print "Deleting property named %s ..." % cmd.propToDelete
        item = boto.sdb.item.Item(domain,cmd.propToDelete)
        domain.delete_item(item)

    if (cmd.bulkFile != None):
        propList = readBulkFile(cmd.bulkFile)
        for prop in propList:
            if (cmd.deleteBulk):
                propName = getItemNameFromObject(prop)
                print "Deleting property: %s" % propName
                item = boto.sdb.item.Item(domain,propName)
                domain.delete_item(item)
            else:
                print "Setting property: %s" % str(prop)
                domain.put_attributes(getItemNameFromObject(prop), prop)

    if (cmd.propName != None):
        print "Setting property: %s" % str(cmd.prop)
        domain.put_attributes(cmd.propName, cmd.prop)

    query = "select * from %s" % cmd.domain
    rs = domain.select(query)
    for j in rs:
        print "Record[%s]: %s" % (j.name, str(j))
