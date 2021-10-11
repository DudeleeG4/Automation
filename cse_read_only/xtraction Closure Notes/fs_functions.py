def writefile(name, content, ext=""):
    try:
        if ext:
            name = name + "." + ext
        file = open(name, "w")
        file.write(content)
        file.close()
    except:
        print("Unable to open and/or write " + str(name))
        exit()

def readfile(name):
    try:
        return open(name, "r").read()
    except:
        print("Unable to open and read " + str(name))
        exit()
