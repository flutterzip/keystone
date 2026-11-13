"""Writes the demo data under assets/data/ (homes, agents, the drawn map and
the rest). Edit the tables here and rerun, or edit the JSON files directly:

    python3 tool/make_seed.py

The JSON is in the shape an API would send, so the same model parsing serves
the seed and a real backend.
"""
import json
import random

OUT = "assets/data/"
N, S, W, E = 38.775, 38.685, -9.225, -9.080


def dump(name, data):
    with open(OUT + name + ".json", "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def rooms(*rs):
    return [{"name": n, "x": x, "y": y, "w": w, "h": h} for n, x, y, w, h in rs]


AM = {
    "garden": "Garden", "pool": "Pool", "parking": "Parking", "terrace": "Terrace",
    "lift": "Lift", "ac": "Air conditioning", "fireplace": "Fireplace",
    "furnished": "Furnished", "pets": "Pets welcome", "view": "River view",
    "storage": "Storage", "concierge": "Concierge",
}

# id, title, address, area, lat, lng, price (whole euros), kind, beds, baths,
# sqm, type, year, listed days ago, featured, photos, agent, amenities
H = [
    ("jacaranda", "Casa do Jacarandá", "Rua do Sacramento 41", "Lapa", 38.7082, -9.1625, 2450000, "sale", 4, 4, 320, "House", 2019, 3, True, 7, "ines",
     ["garden", "parking", "fireplace", "ac", "terrace", "storage"],
     "A black timber house folded around a hundred year old jacaranda. Every room on the ground floor opens to the lawn through glass that slides fully away, and the upper floor floats above it, shaded by its own screen of fins.",
     rooms(("Living", 0, 0, 7.2, 5.4), ("Kitchen", 7.2, 0, 4.6, 5.4), ("Dining", 0, 5.4, 5.0, 3.8), ("Study", 5.0, 5.4, 3.2, 3.8), ("Bath", 8.2, 5.4, 3.6, 2.0), ("Hall", 8.2, 7.4, 3.6, 1.8))),
    ("miradouro", "Miradouro House", "Rua de Alcolena 18", "Restelo", 38.7045, -9.2120, 3200000, "sale", 5, 5, 410, "House", 2021, 12, True, 7, "tomas",
     ["pool", "view", "parking", "terrace", "ac", "garden"],
     "Three white terraces stepping down a hill towards the river. The pool runs the length of the middle terrace and the main bedroom has the top one to itself, with the bridge in view from the bed.",
     rooms(("Living", 0, 0, 8.0, 5.6), ("Kitchen", 8.0, 0, 4.4, 3.4), ("Pantry", 8.0, 3.4, 4.4, 2.2), ("Bedroom", 0, 5.6, 4.6, 4.2), ("Bath", 4.6, 5.6, 2.8, 2.4), ("Terrace", 7.4, 5.6, 5.0, 4.2), ("Hall", 4.6, 8.0, 2.8, 1.8))),
    ("loft", "The Printworks Loft", "Rua da Escola Politécnica 92", "Príncipe Real", 38.7172, -9.1490, 2900, "rent", 2, 2, 128, "Loft", 1924, 1, True, 6, "ines",
     ["lift", "fireplace", "furnished", "pets", "storage"],
     "The top floor of a former printing house, kept open under its original timber trusses. A wood stove sits in the middle of the room, the kitchen runs along one wall and both bedrooms are tucked behind glazed partitions.",
     rooms(("Living", 0, 0, 8.4, 6.0), ("Kitchen", 8.4, 0, 3.6, 6.0), ("Bedroom", 0, 6.0, 4.4, 3.8), ("Bedroom 2", 4.4, 6.0, 3.8, 3.8), ("Bath", 8.2, 6.0, 3.8, 2.2), ("Hall", 8.2, 8.2, 3.8, 1.6))),
    ("alfama", "Alfama Light Apartment", "Rua de São Miguel 27, 2nd floor", "Alfama", 38.7112, -9.1300, 1650, "rent", 1, 1, 62, "Apartment", 1890, 5, False, 7, "bruno",
     ["furnished", "ac", "view"],
     "Two tall windows over the pink and yellow fronts of Alfama. Renovated last year with oak floors, a new kitchen and a bathroom tiled in black and white, and five minutes on foot from the river.",
     rooms(("Living", 0, 0, 5.2, 4.6), ("Kitchen", 5.2, 0, 3.0, 2.6), ("Bath", 5.2, 2.6, 3.0, 2.0), ("Bedroom", 0, 4.6, 4.4, 3.4), ("Hall", 4.4, 4.6, 3.8, 1.6))),
    ("belem", "Belém Garden House", "Travessa das Galinheiras 9", "Belém", 38.6985, -9.2030, 1180000, "sale", 3, 2, 210, "House", 2017, 9, False, 7, "tomas",
     ["garden", "parking", "terrace", "ac", "pets"],
     "Timber, black steel and a walled garden on a quiet lane behind the monastery. The living room is one tall space with a gallery above it, and the kitchen island is long enough to seat six.",
     rooms(("Living", 0, 0, 6.4, 5.2), ("Kitchen", 6.4, 0, 4.2, 5.2), ("Bedroom", 0, 5.2, 4.0, 3.6), ("Bath", 4.0, 5.2, 2.4, 2.2), ("Study", 6.4, 5.2, 4.2, 3.6), ("Hall", 4.0, 7.4, 2.4, 1.4))),
    ("chiado", "Chiado Townhouse", "Rua Ivens 14", "Chiado", 38.7105, -9.1420, 4200, "rent", 3, 3, 190, "Townhouse", 2008, 16, True, 7, "ines",
     ["parking", "lift", "ac", "terrace", "concierge", "storage"],
     "Four floors on one of Chiado's calmest streets, with a garage on the ground floor and a roof terrace at the top. Coffered ceilings, a marble kitchen and a main suite that takes a whole floor.",
     rooms(("Living", 0, 0, 6.0, 5.0), ("Dining", 6.0, 0, 4.0, 5.0), ("Kitchen", 0, 5.0, 4.6, 3.6), ("Bath", 4.6, 5.0, 2.2, 2.0), ("Bedroom", 6.8, 5.0, 3.2, 3.6), ("Hall", 4.6, 7.0, 2.2, 1.6))),
    ("parque", "Parque Residences 4B", "Alameda dos Oceanos 61, 4B", "Parque das Nações", 38.7680, -9.0960, 2100, "rent", 2, 2, 96, "Apartment", 2022, 2, False, 7, "leonor",
     ["lift", "parking", "concierge", "ac", "view", "pool"],
     "A corner apartment in a new building by the water, with a balcony along two sides. Open living and kitchen, two bedrooms with their own bathrooms, and a shared pool on the roof.",
     rooms(("Living", 0, 0, 6.2, 4.8), ("Kitchen", 6.2, 0, 3.2, 3.0), ("Bath", 6.2, 3.0, 3.2, 1.8), ("Bedroom", 0, 4.8, 4.0, 3.6), ("Bedroom 2", 4.0, 4.8, 3.4, 3.6), ("Bath 2", 7.4, 4.8, 2.0, 3.6))),
    ("quinta", "Quinta da Serra", "Calçada do Galvão 120", "Ajuda", 38.7090, -9.1985, 4750000, "sale", 6, 6, 620, "House", 2020, 24, True, 7, "leonor",
     ["pool", "garden", "parking", "terrace", "fireplace", "ac", "storage"],
     "A white villa set in its own grounds on the edge of Monsanto. The pool court is the heart of it: the kitchen, the dining room and a long covered terrace all open onto the water.",
     rooms(("Living", 0, 0, 9.0, 6.0), ("Dining", 9.0, 0, 4.8, 6.0), ("Kitchen", 0, 6.0, 5.4, 4.2), ("Bath", 5.4, 6.0, 3.0, 2.2), ("Bedroom", 8.4, 6.0, 5.4, 4.2), ("Hall", 5.4, 8.2, 3.0, 2.0))),
    ("ourique", "Ourique Garden Flat", "Rua Coelho da Rocha 55, ground floor", "Campo de Ourique", 38.7178, -9.1670, 1950, "rent", 2, 1, 84, "Apartment", 1962, 6, False, 6, "bruno",
     ["garden", "pets", "storage"],
     "A ground floor flat with its own patch of garden, on a street of bakeries and bookshops. Bright living room, a green study that works as a second bedroom, and a dining room for eight.",
     rooms(("Living", 0, 0, 5.6, 4.4), ("Dining", 5.6, 0, 3.6, 4.4), ("Kitchen", 0, 4.4, 3.6, 3.0), ("Bath", 3.6, 4.4, 2.0, 3.0), ("Bedroom", 5.6, 4.4, 3.6, 3.0))),
    ("restelo", "Restelo Pavilion", "Avenida do Restelo 33", "Restelo", 38.7010, -9.2085, 1690000, "sale", 4, 3, 260, "House", 2023, 4, False, 7, "bruno",
     ["garden", "parking", "ac", "terrace", "fireplace"],
     "A new house under a folded white roof, finished this spring. The ground floor is one room from the street to the garden, with a stair of open oak treads rising through the middle of it.",
     rooms(("Living", 0, 0, 7.0, 5.0), ("Kitchen", 7.0, 0, 4.0, 5.0), ("Bedroom", 0, 5.0, 4.2, 3.8), ("Bath", 4.2, 5.0, 2.6, 2.0), ("Garage", 6.8, 5.0, 4.2, 3.8), ("Hall", 4.2, 7.0, 2.6, 1.8))),
]

homes = []
for (id_, title, addr, area, lat, lng, price, kind, beds, baths, sqm, typ, year, listed, feat, n, agent, am, desc, rs) in H:
    homes.append({
        "id": id_, "title": title, "address": addr, "area": area,
        "coordinates": {"lat": lat, "lng": lng},
        "price": {"amount": price * 100, "currency": "EUR"},
        "listing": kind, "beds": beds, "baths": baths, "areaSqm": sqm, "type": typ,
        "yearBuilt": year, "listedDaysAgo": listed, "featured": feat,
        "amenities": [AM[a] for a in am],
        "photos": [f"asset:homes/{id_}-{i}.jpg" for i in range(1, n + 1)],
        "description": desc, "rooms": rs, "agentId": agent,
    })
dump("homes", homes)

dump("agents", [
    {"id": "ines", "name": "Inês Carvalho", "agency": "{app} Chiado", "phone": "+351 21 555 0142", "email": "ines@keystone.example", "photo": "asset:people/agent-1.jpg", "replyMinutes": 12},
    {"id": "tomas", "name": "Tomás Ribeiro", "agency": "{app} Belém", "phone": "+351 21 555 0167", "email": "tomas@keystone.example", "photo": "asset:people/agent-2.jpg", "replyMinutes": 25},
    {"id": "leonor", "name": "Leonor Matos", "agency": "{app} Riverside", "phone": "+351 21 555 0119", "email": "leonor@keystone.example", "photo": "asset:people/agent-3.jpg", "replyMinutes": 8},
    {"id": "bruno", "name": "Bruno Faria", "agency": "{app} Estrela", "phone": "+351 21 555 0188", "email": "bruno@keystone.example", "photo": "asset:people/agent-4.jpg", "replyMinutes": 40},
])

# Times are minutes from first launch (negative is the past), so the demo
# never goes stale: one viewing is always about to start on a fresh install.
dump("viewings", [
    {"id": "v-soon", "homeId": "loft", "inMinutes": 45, "mode": "inPerson"},
    {"id": "v-next", "homeId": "jacaranda", "inMinutes": 3 * 1440 + 150, "mode": "video"},
    {"id": "v-past", "homeId": "chiado", "inMinutes": -6 * 1440, "mode": "inPerson"},
    {"id": "v-past-2", "homeId": "belem", "inMinutes": -2 * 1440 - 200, "mode": "inPerson"},
    {"id": "v-cancelled", "homeId": "parque", "inMinutes": 2 * 1440, "mode": "video", "cancelledMinutesAgo": 300},
])

dump("threads", [
    {"id": "t-ines", "agentId": "ines", "homeId": "loft", "readMinutesAgo": 200, "messages": [
        {"fromMe": True, "minutesAgo": 1500, "text": "Hello Inês, is the Printworks Loft still available from December?"},
        {"fromMe": False, "minutesAgo": 1460, "text": "It is. The current tenants leave on the 28th, so you could have the keys from the 1st of December."},
        {"fromMe": True, "minutesAgo": 1440, "text": "Perfect. I have booked a viewing."},
        {"fromMe": False, "minutesAgo": 32, "text": "See you there. The entrance is the green door between the bakery and the bookshop. Ring the top bell and I will come down."},
    ]},
    {"id": "t-tomas", "agentId": "tomas", "homeId": "belem", "readMinutesAgo": 10, "messages": [
        {"fromMe": False, "minutesAgo": 2900, "text": "Thank you for coming to see the Garden House. I have passed your offer to the owners."},
        {"fromMe": True, "minutesAgo": 2880, "text": "Thank you. Do you know when they will decide?"},
        {"fromMe": False, "minutesAgo": 2870, "text": "They have asked for a couple of days. I will message you the moment I hear."},
    ]},
    {"id": "t-leonor", "agentId": "leonor", "homeId": "parque", "readMinutesAgo": 100, "messages": [
        {"fromMe": False, "minutesAgo": 320, "text": "I am sorry, the owner needs the apartment that afternoon. Would another day suit you?"},
        {"fromMe": True, "minutesAgo": 300, "text": "No problem, I will book another time."},
    ]},
])

dump("applications", [
    {"id": "a-chiado", "homeId": "chiado", "kind": "application", "submittedMinutesAgo": 3 * 1440, "moveInDays": 21, "note": "Two adults, no pets. Looking for a two year lease."},
    {"id": "a-belem", "homeId": "belem", "kind": "offer", "submittedMinutesAgo": 50, "offer": {"amount": 115000000, "currency": "EUR"}, "note": "Subject to survey. Mortgage agreed in principle."},
])

dump("saved_searches", [
    {"id": "s-rent", "name": "Two beds near the river", "alerts": True, "filter": {"listing": "rent", "minBeds": 2, "maxPrice": 300000, "amenities": []}},
    {"id": "s-buy", "name": "Family house with a garden", "alerts": False, "filter": {"listing": "sale", "minBeds": 3, "types": ["House"], "amenities": ["Garden"]}},
])

dump("documents", [
    {"id": "d-id", "name": "Passport", "kind": "Identity", "addedMinutesAgo": 14 * 1440},
    {"id": "d-income", "name": "Payslips, last three months", "kind": "Proof of income", "addedMinutesAgo": 25},
])

dump("cards", [
    {"id": "visa", "brand": "Visa", "last4": "4242", "expMonth": 8, "expYear": 2029, "holder": "Olympicson"},
    {"id": "mc", "brand": "Mastercard", "last4": "0002", "expMonth": 3, "expYear": 2028, "holder": "Olympicson"},
])

dump("profile", {"name": "Olympicson", "email": "hello@flutterzip.com", "phone": "+1 810 123 4567", "avatar": "asset:people/olympicson.png", "memberNumber": "KS 0417 2026", "memberSince": 2024})

dump("demo", {"demoEmail": "hello@flutterzip.com", "wrongPassword": "wrongpass", "decliningCardLast4": "0002",
              "recentlyViewed": ["alfama", "miradouro", "chiado"], "saved": ["loft", "jacaranda", "belem"],
              "reservationFee": {"amount": 250000, "currency": "EUR"}})

# --- the drawn map, on a unit square (x east, y south) ----------------------
random.seed(7)
water = [[0, .93], [.15, .905], [.35, .87], [.52, .82], [.62, .775], [.72, .72], [.80, .60], [.86, .42], [.905, .22], [.93, 0], [1, 0], [1, 1], [0, 1]]
parks = [
    [[.13, .34], [.22, .30], [.31, .36], [.34, .47], [.31, .58], [.22, .63], [.14, .58], [.10, .46]],
    [[.49, .47], [.54, .46], [.55, .57], [.50, .58]],
    [[.415, .655], [.455, .65], [.46, .69], [.42, .695]],
    [[.08, .835], [.19, .82], [.20, .86], [.09, .875]],
    [[.60, .16], [.68, .14], [.70, .22], [.62, .25]],
]
avenues = [
    [[0, .80], [.20, .78], [.40, .755], [.58, .70], [.70, .64], [.78, .54], [.84, .36], [.88, .16], [.90, 0]],
    [[.52, 0], [.525, .20], [.52, .46], [.535, .60], [.56, .72]],
    [[0, .26], [.20, .24], [.40, .27], [.60, .30], [.84, .34]],
    [[.36, .30], [.37, .50], [.40, .64], [.43, .76]],
    [[.34, .50], [.50, .47], [.66, .50], [.78, .54]],
]
streets = []
for i in range(1, 16):
    y = i / 16 + random.uniform(-.012, .012)
    t = random.uniform(-.03, .03)
    streets.append([[0, round(y, 3)], [.5, round(y + t, 3)], [1, round(y + t * 1.6, 3)]])
for i in range(1, 16):
    x = i / 16 + random.uniform(-.012, .012)
    t = random.uniform(-.03, .03)
    streets.append([[round(x, 3), 0], [round(x + t, 3), .5], [round(x + t * 1.6, 3), 1]])
labels = [
    {"name": "Alfama", "lat": 38.7120, "lng": -9.1285}, {"name": "Chiado", "lat": 38.7100, "lng": -9.1425},
    {"name": "Príncipe Real", "lat": 38.7175, "lng": -9.1495}, {"name": "Lapa", "lat": 38.7078, "lng": -9.1630},
    {"name": "Campo de Ourique", "lat": 38.7185, "lng": -9.1675}, {"name": "Belém", "lat": 38.6975, "lng": -9.2010},
    {"name": "Restelo", "lat": 38.7040, "lng": -9.2110}, {"name": "Ajuda", "lat": 38.7095, "lng": -9.1975},
    {"name": "Parque das Nações", "lat": 38.7675, "lng": -9.0965}, {"name": "Alvalade", "lat": 38.7530, "lng": -9.1440},
]
dump("map", {"bounds": {"north": N, "south": S, "west": W, "east": E}, "water": water, "parks": parks,
             "avenues": avenues, "streets": streets, "areas": labels, "waterName": "Tagus"})
print("seed written")
