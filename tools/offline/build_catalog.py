"""Build a traceable offline catalogue from USDA SR Legacy CSV (CC0).

Recipe weights below are explicit example *served edible* weights, not raw
recipe yields. No whole-dish research energy is mislabeled as energy/100 g.
Run with the extracted USDA CSV folder as the only argument.
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "https://fdc.nal.usda.gov/"

# key: USDA ID, Chinese label, category, extra searchable aliases.
INGREDIENTS = {
    "rice": (168878, "熟米饭", "主食", ["白饭", "白米饭"]),
    "raw_rice": (168877, "生大米", "原料与调味", []),
    "rice_noodles": (168914, "熟米粉", "主食", ["米制面条"]),
    "egg": (173424, "水煮鸡蛋", "蛋奶", ["白煮蛋", "煮鸡蛋"]),
    "chicken_skin": (171051, "熟鸡肉（带皮，炖制）", "肉与海鲜", []),
    "chicken": (171451, "熟鸡肉（去皮，炖制）", "肉与海鲜", []),
    "breast": (171478, "熟鸡胸肉（炖制）", "肉与海鲜", []),
    "pork": (168250, "熟猪里脊（烤制）", "肉与海鲜", ["熟瘦猪肉"]),
    "mince": (167903, "熟猪肉末", "肉与海鲜", []),
    "ribs": (167854, "熟排骨肉（炖制，去骨）", "肉与海鲜", []),
    "duck": (172409, "烤鸭肉（带皮）", "肉与海鲜", ["烧鸭", "烤鸭"]),
    "beef": (168634, "熟牛肉（烤西冷，去脂）", "肉与海鲜", []),
    "shrimp": (175180, "熟虾仁", "肉与海鲜", ["白灼虾", "虾肉"]),
    "bass": (173694, "熟鲈鱼肉（干热烹调）", "肉与海鲜", []),
    "tilapia": (175177, "熟罗非鱼肉（干热烹调）", "肉与海鲜", []),
    "tofu": (172475, "硬豆腐", "豆制品", ["豆腐"]),
    "greens": (169392, "熟芥兰", "蔬菜", ["芥藍"]),
    "bokchoy": (170391, "熟小白菜（沥水）", "蔬菜", ["小棠菜"]),
    "spinach": (168463, "熟菠菜（沥水）", "蔬菜", []),
    "mushroom": (168437, "熟香菇", "蔬菜", ["冬菇"]),
    "corn": (169999, "熟甜玉米粒", "蔬菜", ["粟米"]),
    "peas": (170420, "熟青豌豆", "蔬菜", []),
    "carrot": (170394, "熟胡萝卜", "蔬菜", ["红萝卜"]),
    "tomato": (170050, "熟番茄", "蔬菜", ["西红柿"]),
    "potato": (170440, "水煮土豆（去皮）", "主食", ["马铃薯", "薯仔"]),
    "edamame": (169283, "熟毛豆仁", "豆制品", []),
    "garlic": (169230, "生蒜", "原料与调味", ["蒜蓉", "大蒜"]),
    "ginger": (169231, "生姜", "原料与调味", ["姜"]),
    "scallion": (170005, "小葱", "原料与调味", ["葱", "青葱"]),
    "soy": (174277, "酱油", "原料与调味", ["生抽"]),
    "hoisin": (172886, "海鲜酱", "原料与调味", []),
    "oil": (172336, "菜籽油", "原料与调味", ["食用油", "植物油"]),
    "sugar": (169655, "白砂糖", "原料与调味", ["白糖"]),
    "starch": (169698, "玉米淀粉", "原料与调味", ["生粉"]),
    "flour": (169761, "小麦粉", "原料与调味", ["面粉"]),
    "milk": (171265, "全脂牛奶", "蛋奶", ["牛奶"]),
    "low_milk": (170872, "低脂牛奶", "蛋奶", []),
    "bread": (174924, "白面包", "主食", ["吐司"]),
    "banana": (173944, "香蕉", "水果", []),
    "apple": (167793, "苹果（富士，带皮）", "水果", ["苹果"]),
    "water": (173647, "饮用水", "饮品", ["白开水"]),
    "noodles": (168919, "熟鸡蛋面", "主食", ["熟面条"]),
}

# Example compositions, all weights are grams of edible ingredients as served.
# Cooking methods/proxies remain visible in each source ingredient description.
RECIPES = [
    ("白切鸡（带皮，参考）", "粤式肉菜", ["白斩鸡"], {"chicken_skin": 300, "ginger": 5, "scallion": 10, "oil": 5, "soy": 10}),
    ("白切鸡（去皮，参考）", "粤式肉菜", ["白斩鸡去皮"], {"chicken": 300, "ginger": 5, "scallion": 10, "soy": 10}),
    ("豉油鸡（参考）", "粤式肉菜", ["酱油鸡"], {"chicken_skin": 300, "soy": 25, "sugar": 10, "water": 30}),
    ("姜葱鸡（参考）", "粤式肉菜", ["葱姜鸡"], {"chicken": 300, "ginger": 10, "scallion": 30, "oil": 15, "soy": 15}),
    ("盐焗鸡（参考）", "粤式肉菜", [], {"chicken_skin": 300, "ginger": 5, "oil": 5}),
    ("香菇滑鸡（参考）", "粤式肉菜", ["冬菇滑鸡"], {"chicken": 200, "mushroom": 100, "oil": 8, "soy": 10, "starch": 5, "water": 30}),
    ("蒜蓉蒸排骨（参考）", "粤式肉菜", ["蒸排骨"], {"ribs": 250, "garlic": 12, "soy": 10, "oil": 5, "water": 20}),
    ("蒸肉饼（参考）", "粤式肉菜", [], {"mince": 200, "soy": 10, "starch": 5, "water": 60}),
    ("玉米蒸肉饼（参考）", "粤式肉菜", ["粟米肉饼"], {"mince": 180, "corn": 100, "soy": 10, "water": 50}),
    ("香菇蒸肉饼（参考）", "粤式肉菜", ["冬菇肉饼"], {"mince": 180, "mushroom": 100, "soy": 10, "water": 50}),
    ("叉烧（瘦肉参考配方）", "粤式肉菜", ["蜜汁叉烧"], {"pork": 250, "hoisin": 25, "sugar": 15, "soy": 10, "oil": 5}),
    ("清蒸鲈鱼（参考）", "鱼虾", ["蒸鱼"], {"bass": 300, "ginger": 10, "scallion": 20, "soy": 15, "oil": 10}),
    ("清蒸罗非鱼（参考）", "鱼虾", [], {"tilapia": 300, "ginger": 10, "scallion": 20, "soy": 15, "oil": 8}),
    ("蒜蓉虾仁（参考）", "鱼虾", [], {"shrimp": 250, "garlic": 15, "oil": 10, "soy": 10}),
    ("滑蛋虾仁（参考）", "鱼虾", ["虾仁炒蛋"], {"shrimp": 150, "egg": 150, "oil": 10, "scallion": 10}),
    ("芥兰炒牛肉（参考）", "粤式家常", [], {"greens": 200, "beef": 150, "oil": 12, "soy": 12, "starch": 4}),
    ("蒜蓉芥兰（参考）", "粤式蔬菜", ["炒芥兰"], {"greens": 300, "garlic": 12, "oil": 12}),
    ("白灼芥兰（参考）", "粤式蔬菜", [], {"greens": 300, "soy": 15, "oil": 5}),
    ("蒜蓉小白菜（参考）", "粤式蔬菜", ["蒜蓉小棠菜"], {"bokchoy": 300, "garlic": 12, "oil": 12}),
    ("白灼小白菜（参考）", "粤式蔬菜", ["白灼小棠菜"], {"bokchoy": 300, "soy": 12, "oil": 5}),
    ("上汤菠菜（参考）", "粤式蔬菜", [], {"spinach": 250, "egg": 50, "oil": 5, "water": 100}),
    ("香菇扒小白菜（参考）", "粤式蔬菜", ["冬菇扒小棠菜"], {"bokchoy": 250, "mushroom": 100, "oil": 8, "soy": 15, "starch": 5, "water": 30}),
    ("番茄炒蛋（参考）", "粤式家常", ["西红柿炒鸡蛋"], {"tomato": 250, "egg": 150, "oil": 12, "sugar": 5}),
    ("家常煎豆腐（参考）", "粤式家常", [], {"tofu": 250, "oil": 15, "soy": 15, "scallion": 15}),
    ("香菇焖豆腐（参考）", "粤式家常", ["冬菇豆腐"], {"tofu": 200, "mushroom": 100, "oil": 8, "soy": 15, "water": 50}),
    ("虾仁蒸蛋（参考）", "粤式家常", [], {"egg": 100, "shrimp": 80, "water": 180, "soy": 8, "oil": 3}),
    ("水蒸蛋（参考）", "粤式家常", ["蒸水蛋", "鸡蛋羹"], {"egg": 100, "water": 150, "soy": 8, "oil": 3}),
    ("白粥（参考浓稠度）", "粥", ["大米粥", "稀饭"], {"rice": 150, "water": 450}),
    ("鸡丝粥（参考）", "粥", [], {"rice": 150, "water": 400, "chicken": 60, "ginger": 3}),
    ("鲜虾粥（参考）", "粥", [], {"rice": 150, "water": 400, "shrimp": 60, "ginger": 3}),
    ("瘦肉粥（参考）", "粥", [], {"rice": 150, "water": 400, "pork": 60, "ginger": 3}),
    ("香菇鸡粥（参考）", "粥", ["冬菇鸡粥"], {"rice": 150, "water": 400, "chicken": 50, "mushroom": 50}),
    ("白切鸡饭（参考，含米饭）", "饭类", ["鸡饭"], {"rice": 250, "chicken_skin": 120, "bokchoy": 80, "soy": 10, "oil": 5}),
    ("豉油鸡饭（参考，含米饭）", "饭类", [], {"rice": 250, "chicken_skin": 120, "bokchoy": 80, "soy": 20, "sugar": 5}),
    ("叉烧饭（参考，含米饭）", "饭类", [], {"rice": 250, "pork": 100, "hoisin": 15, "sugar": 10, "bokchoy": 80, "oil": 5}),
    ("烧鸭饭（参考，含米饭）", "饭类", [], {"rice": 250, "duck": 120, "bokchoy": 80, "soy": 10}),
    ("蛋炒饭（参考）", "饭类", ["炒饭"], {"rice": 250, "egg": 100, "scallion": 15, "oil": 15, "soy": 10}),
    ("扬州炒饭（参考）", "饭类", [], {"rice": 250, "egg": 75, "shrimp": 50, "peas": 40, "carrot": 40, "oil": 15}),
    ("虾仁炒饭（参考）", "饭类", [], {"rice": 250, "shrimp": 100, "egg": 50, "scallion": 15, "oil": 15, "soy": 10}),
    ("香菇鸡饭（参考，含米饭）", "饭类", [], {"rice": 250, "chicken": 100, "mushroom": 60, "soy": 12, "oil": 8}),
    ("牛肉炒米粉（参考）", "粉面", ["干炒牛河", "牛肉河粉"], {"rice_noodles": 250, "beef": 100, "scallion": 30, "oil": 20, "soy": 20}),
    ("豉油皇炒面（参考）", "粉面", ["酱油炒面"], {"noodles": 250, "scallion": 30, "oil": 18, "soy": 20, "sugar": 5}),
    ("鸡丝炒米粉（参考）", "粉面", [], {"rice_noodles": 250, "chicken": 80, "carrot": 50, "scallion": 20, "oil": 15, "soy": 15}),
    ("鲜虾汤面（参考，含汤）", "粉面", [], {"noodles": 200, "shrimp": 80, "bokchoy": 60, "water": 300, "soy": 10, "oil": 3}),
    ("鸡丝汤面（参考，含汤）", "粉面", [], {"noodles": 200, "chicken": 80, "bokchoy": 60, "water": 300, "soy": 10, "oil": 3}),
    ("番茄蛋汤（参考，含汤）", "汤", [], {"tomato": 150, "egg": 50, "water": 400, "oil": 3}),
    ("玉米鸡肉汤（参考，含肉）", "汤", [], {"corn": 100, "chicken": 80, "carrot": 80, "water": 400}),
    ("香菇豆腐汤（参考，含配料）", "汤", [], {"tofu": 150, "mushroom": 80, "water": 400, "oil": 3}),
    ("清蒸蛋白鸡肉饼（参考）", "粤式家常", [], {"chicken": 150, "egg": 50, "water": 80, "soy": 8}),
    ("粟米炒虾仁（参考）", "粤式家常", [], {"corn": 150, "shrimp": 150, "carrot": 50, "oil": 10}),
]


def build(csv_dir: Path):
    with (csv_dir / "food.csv").open(encoding="utf-8-sig", newline="") as handle:
        foods = {int(row["fdc_id"]): row for row in csv.DictReader(handle)}
    ids = {entry[0] for entry in INGREDIENTS.values()}
    energy = {}
    with (csv_dir / "food_nutrient.csv").open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            food_id = int(row["fdc_id"])
            if food_id in ids and row["nutrient_id"] == "1008":
                energy[food_id] = float(row["amount"])
    assert ids <= energy.keys(), f"Missing kcal data: {ids - energy.keys()}"
    result = []
    provenance = []
    for key, (food_id, name, category, aliases) in INGREDIENTS.items():
        description = foods[food_id]["description"]
        note = "每100克可食部分；生熟与烹调方式以本条名称和来源原文为准。"
        result.append(dict(id=f"usda-{food_id}", name=name, kcal100=energy[food_id],
                           category=category, aliases=aliases, note=note, custom=False,
                           source=f"USDA SR Legacy 2018 · FDC {food_id} · CC0 1.0\n{description}\n{SOURCE}"))
        provenance.append(dict(fdc_id=food_id, name=name, original=description,
                               kcal100=energy[food_id]))
    for index, (name, category, aliases, composition) in enumerate(RECIPES, 1):
        weight = sum(composition.values())
        calories = sum(energy[INGREDIENTS[key][0]] * grams / 100
                       for key, grams in composition.items())
        components = "；".join(f"{INGREDIENTS[key][1]} {grams}克"
                               for key, grams in composition.items())
        originals = "\n".join(f"FDC {INGREDIENTS[key][0]}: {foods[INGREDIENTS[key][0]]['description']}"
                               for key in composition)
        result.append(dict(id=f"recipe-{index:03d}", name=name,
                           kcal100=round(calories / weight * 100, 6),
                           category=category, aliases=aliases, custom=False,
                           note=f"示例配方估算，称食用可食部分；整份参考重{weight}克。配料、用油和含水量不同，热量会变化。带骨菜只称实际食用肉重。",
                           source=f"本项目示例配方（非餐厅实测）\n{components}\n"
                           f"配料重按熟制可食部分及调料重计算，整份{weight}克，约{calories:.1f}千卡。"
                           "为营养近似组合，蒸/煮/炒等食材可能使用下列相近烹调数据；不主张完全等同。\n"
                           f"{originals}\n食材来源：USDA SR Legacy 2018，CC0 1.0\n{SOURCE}"))
    assert len({food["id"] for food in result}) == len(result)
    assert all(0 <= food["kcal100"] <= 1000 for food in result)
    output = ROOT / "assets/offline"
    output.mkdir(parents=True, exist_ok=True)
    (output / "foods.json").write_text(json.dumps(dict(version=1, foods=result),
        ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output / "usda_provenance.json").write_text(json.dumps(provenance,
        ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(result)} foods: {len(INGREDIENTS)} source ingredients + {len(RECIPES)} example recipes")


if __name__ == "__main__":
    build(Path(sys.argv[1]))
