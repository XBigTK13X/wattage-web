import json
import math
import os
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
AUTOMA_SRC = os.path.join(ROOT_DIR, "airef", "automa", "src")
sys.path.insert(0, os.path.join(ROOT_DIR, "airef", "automa"))

from src.board.germany import germany
from src.board.united_states_of_america import united_states_of_america
from src.plant_deck.base_game_plants import base_game_plants
from src.plant_deck.new_plants_1 import new_plants_1
from src.plant_deck.new_plants_2 import new_plants_2

DIRECTION_VECTORS = {
    "n": (0.0, -1.0),
    "ne": (0.707, -0.707),
    "e": (1.0, 0.0),
    "se": (0.707, 0.707),
    "s": (0.0, 1.0),
    "sw": (-0.707, 0.707),
    "w": (-1.0, 0.0),
    "nw": (-0.707, -0.707),
}

OPPOSITE_DIRECTION = {
    "n": "s",
    "s": "n",
    "e": "w",
    "w": "e",
    "ne": "sw",
    "sw": "ne",
    "nw": "se",
    "se": "nw",
}

REGION_COLORS = {
    1: "#3a7ca5",
    2: "#8f5d9c",
    3: "#d97724",
    4: "#c94c4c",
    5: "#4a8f5c",
    6: "#c7a328",
}

MAX_PLANTS_BY_COUNT = {2: 4, 3: 3, 4: 3, 5: 3, 6: 3}


def format_city_name(city_id):
    return city_id.replace("-", " ").title()


def compute_city_positions(city_ids, connections):
    positions = {}
    for index, city_id in enumerate(city_ids):
        angle = (2.0 * math.pi * index) / max(1, len(city_ids))
        positions[city_id] = [600.0 + 380.0 * math.cos(angle), 400.0 + 260.0 * math.sin(angle)]

    directed_edges = []
    for source_city, direction, target_city, _cost in connections:
        vec = DIRECTION_VECTORS.get(direction, (1.0, 0.0))
        directed_edges.append((source_city, target_city, vec))
        opp = DIRECTION_VECTORS.get(OPPOSITE_DIRECTION.get(direction, ""), (-vec[0], -vec[1]))
        directed_edges.append((target_city, source_city, opp))

    target_distance = 175.0
    for _iteration in range(280):
        forces = {city_id: [0.0, 0.0] for city_id in city_ids}
        for idx_first in range(len(city_ids)):
            city_first = city_ids[idx_first]
            for idx_second in range(idx_first + 1, len(city_ids)):
                city_second = city_ids[idx_second]
                dx = positions[city_second][0] - positions[city_first][0]
                dy = positions[city_second][1] - positions[city_first][1]
                dist_sq = max(16.0, dx * dx + dy * dy)
                dist = math.sqrt(dist_sq)
                repulse = 19000.0 / dist_sq
                fx = (dx / dist) * repulse
                fy = (dy / dist) * repulse
                forces[city_first][0] -= fx
                forces[city_first][1] -= fy
                forces[city_second][0] += fx
                forces[city_second][1] += fy

        for source_city, target_city, vec in directed_edges:
            desired_x = positions[source_city][0] + vec[0] * target_distance
            desired_y = positions[source_city][1] + vec[1] * target_distance
            pull_x = (desired_x - positions[target_city][0]) * 0.09
            pull_y = (desired_y - positions[target_city][1]) * 0.09
            forces[target_city][0] += pull_x
            forces[target_city][1] += pull_y
            forces[source_city][0] -= pull_x * 0.35
            forces[source_city][1] -= pull_y * 0.35

        for city_id in city_ids:
            positions[city_id][0] += max(-22.0, min(22.0, forces[city_id][0]))
            positions[city_id][1] += max(-22.0, min(22.0, forces[city_id][1]))

    min_x = min(pos[0] for pos in positions.values())
    min_y = min(pos[1] for pos in positions.values())
    for city_id in city_ids:
        positions[city_id][0] = round(positions[city_id][0] - min_x + 120.0, 1)
        positions[city_id][1] = round(positions[city_id][1] - min_y + 100.0, 1)
    return positions


def convert_board(board_id, board_data):
    city_ids = [entry[1] for entry in board_data["cities"]]
    positions = compute_city_positions(city_ids, board_data["connections"])

    regions = {}
    for region_num in sorted({entry[0] for entry in board_data["cities"]}):
        region_key = "region_" + str(region_num)
        regions[region_key] = {
            "name": "Region " + str(region_num),
            "color": REGION_COLORS.get(region_num, "#4a6fa5"),
        }

    region_connections = []
    for pair in board_data["region_connections"]:
        region_connections.append(["region_" + str(pair[0]), "region_" + str(pair[1])])

    cities = []
    for region_num, city_id, connection_count in board_data["cities"]:
        cities.append({
            "id": city_id,
            "name": format_city_name(city_id),
            "region_id": "region_" + str(region_num),
            "position": positions[city_id],
            "max_connections": connection_count,
        })

    connections = []
    for source_city, direction, target_city, cost in board_data["connections"]:
        connections.append({
            "from": source_city,
            "direction": direction,
            "to": target_city,
            "cost": cost,
        })

    player_count_info = {}
    for index, row in enumerate(board_data["player_count_info"]):
        player_count = index + 2
        player_count_info[str(player_count)] = {
            "regions": row[0],
            "removed_plants": row[1],
            "max_plants": MAX_PLANTS_BY_COUNT[player_count],
            "step_two_cities": row[3],
            "end_game_cities": row[4],
            "refill": row[5],
        }

    return {
        "id": board_id,
        "display_name": board_data["name"],
        "start_resources": list(board_data["start_resources"]),
        "player_count_info": player_count_info,
        "regions": regions,
        "region_connections": region_connections,
        "cities": cities,
        "connections": connections,
        "automa_start_cities": dict(board_data["automa_start_cities"]),
        "rule_overrides": {},
    }


def verify_board(board_json, reference_data):
    assert len(board_json["cities"]) == 42, f"Expected 42 cities, got {len(board_json['cities'])}"
    assert len(board_json["regions"]) == 6, f"Expected 6 regions, got {len(board_json['regions'])}"
    assert len(board_json["connections"]) == len(reference_data["connections"])

    city_set = {city["id"] for city in board_json["cities"]}
    adjacency = {city_id: set() for city_id in city_set}
    for edge in board_json["connections"]:
        assert edge["from"] in city_set and edge["to"] in city_set
        adjacency[edge["from"]].add(edge["to"])
        adjacency[edge["to"]].add(edge["from"])

    visited = set()
    stack = [next(iter(city_set))]
    while stack:
        current = stack.pop()
        if current in visited:
            continue
        visited.add(current)
        stack.extend(adjacency[current] - visited)
    assert len(visited) == 42, "Map graph is not a single connected component"

    edge_map = {(edge["from"], edge["to"]): edge["cost"] for edge in board_json["connections"]}
    for source_city, _dir, target_city, cost in reference_data["connections"]:
        assert edge_map.get((source_city, target_city)) == cost


def verify_decks():
    fuel_map = {
        "coal": "coal",
        "oil": "oil",
        "trash": "garbage",
        "nuke": "uranium",
        "wind": "ecological",
        "oil/coal": "hybrid_oil_coal",
        "oil/trash": "hybrid_oil_garbage",
        "step3": "step3",
    }
    expected_sets = [
        ("base_game", base_game_plants),
        ("new_plants_1", new_plants_1),
        ("new_plants_2", new_plants_2),
    ]
    for index, (deck_id, raw_cards) in enumerate(expected_sets, start=1):
        deck_path = os.path.join(ROOT_DIR, "data", "decks", deck_id + ".json")
        with open(deck_path, "r", encoding="utf-8") as handle:
            deck_json = json.load(handle)
        cards = deck_json["cards"]
        assert len(cards) == len(raw_cards), f"{deck_id} count mismatch"
        for card_index, (cost, amount, kind, power) in enumerate(raw_cards):
            parsed = cards[card_index]
            assert parsed["number"] == cost
            assert parsed["fuel_cost"] == amount
            assert parsed["fuel_type"] == fuel_map[kind]
            assert parsed["cities_powered"] == power
        print(f"Verified deck {index}/{len(expected_sets)}: {deck_id} ({len(cards)} cards)")


def main():
    maps_dir = os.path.join(ROOT_DIR, "data", "maps")
    os.makedirs(maps_dir, exist_ok=True)
    boards = [
        ("germany", germany),
        ("united_states", united_states_of_america),
    ]
    for index, (board_id, board_data) in enumerate(boards, start=1):
        print(f"Exporting and verifying map {index}/{len(boards)}: {board_id}")
        converted = convert_board(board_id, board_data)
        verify_board(converted, board_data)
        out_path = os.path.join(maps_dir, board_id + ".json")
        with open(out_path, "w", encoding="utf-8") as handle:
            json.dump(converted, handle, indent=2)
    verify_decks()
    print("All base maps and plant decks verified successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
