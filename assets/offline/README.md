# Offline food catalogue, revision 1

The catalogue contains 42 source ingredients/foods and 50 **example recipe
estimates**, generated reproducibly by `tools/offline/build_catalog.py`.

Ingredient data: USDA FoodData Central, SR Legacy, April 2018. Source:
https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip

USDA states the data are public domain, CC0 1.0:
https://fdc.nal.usda.gov/

Each ingredient retains its FDC ID, original English description and energy
per 100 grams of edible portion. The Chinese name preserves cooked/raw state;
recipes explicitly disclose any approximate ingredient/cooking substitution.
Milk and water are counted in grams, not silently converted from millilitres.

Recipe compositions and Chinese labels were authored for this application.
These compositions are released under CC0 1.0. Recipe entries list component
weights, total served edible weight, total recipe calories, ingredient IDs and
the calculation basis. They are reference examples, **not laboratory results**,
not nutritionally identical to every restaurant dish, and not a transcription
of the 500-dish Figshare workbook. No energy figure from a whole research recipe
has been relabeled as calories per 100 grams of cooked food.

The downloaded research workbook `Cantonese cuisines.xlsx` was inspected:
500 records, 46 columns, with total recipe energy and serving count, but no
served edible gram weight. It remains a research source, not an imported
per-100-gram food catalogue. MD5: f0124bf06bc1ce7403077dc1ad8eb67a.
https://doi.org/10.6084/m9.figshare.28457018.v4 (CC BY 4.0)

Rebuild with bundled/system Python (standard library only):

    python tools/offline/build_catalog.py <extracted-USDA-CSV-directory>

Then run `flutter test test/offline/` for catalogue integrity and calculations.
