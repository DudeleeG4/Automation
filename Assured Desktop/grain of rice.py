Grains = 1
Square = 1
Total = 1

List = []
while (Square < 65):
	if Grains > 86500000000000000:
		Translation = Grains/86500000000000000.0
		Unit = "x (2009) Chinese Coal Reserves"
	elif Grains > 50000000000000000:
		Translation = Grains/50000000000000000.0
		Unit = "Cubic Km"
	elif Grains > 330000000000000:
		Translation = Grains/330000000000000.0
		Unit = "x Hoover Dam"
	elif Grains > 18250000000000:
		Translation = Grains/18250000000000.0
		Unit = "x Empire State Building"
	elif Grains > 2600000000000:
		Translation = Grains/2600000000000.0
		Unit = "x Titanic"
	elif Grains > 50000000:
		Translation = Grains/50000000.0
		Unit = "Tons"
	elif Grains > 50000:
		Translation = Grains/50000.0
		Unit = "KG"
	else: 
		Translation = Grains
		Unit = "Grains"
	List.append({
	"Square":Square,
	"Amount on Square":str(Translation) + " " + Unit,
	"Total Grains":str(Total) + " grains" 
	})
	Square = Square + 1
	Grains = Grains + Grains
	Total = Total + Grains
for Element in List:
	print Element