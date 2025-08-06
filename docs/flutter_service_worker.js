'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"webapp-backup-20250805-040114/flutter_bootstrap.js": "c505aa4dccb091b27ae4409e942bbf6a",
"webapp-backup-20250805-040114/version.json": "b5d52a3eae84d49b4b5b74717cd65ed8",
"webapp-backup-20250805-040114/index.html": "9b5f600d50995f7b4bdf54d10d599ded",
"webapp-backup-20250805-040114/main.dart.js": "d8382e8f0aad6100c37159d32e145702",
"webapp-backup-20250805-040114/flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"webapp-backup-20250805-040114/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"webapp-backup-20250805-040114/icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"webapp-backup-20250805-040114/icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"webapp-backup-20250805-040114/icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"webapp-backup-20250805-040114/icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"webapp-backup-20250805-040114/manifest.json": "9863581815ecdce27aa6b22a719a945c",
"webapp-backup-20250805-040114/assets/AssetManifest.json": "dcbf689527d0cb649fe7aae52ae610e7",
"webapp-backup-20250805-040114/assets/NOTICES": "16be19a3048da70004d86b1298d548da",
"webapp-backup-20250805-040114/assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"webapp-backup-20250805-040114/assets/AssetManifest.bin.json": "32f229dc0ae013e5a86b5d8965a757c4",
"webapp-backup-20250805-040114/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"webapp-backup-20250805-040114/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"webapp-backup-20250805-040114/assets/AssetManifest.bin": "d82c224a6c220489bec5e37a1e183b77",
"webapp-backup-20250805-040114/assets/fonts/MaterialIcons-Regular.otf": "911780a8e7e9d114988df7fd0b8182c2",
"webapp-backup-20250805-040114/assets/data/skills_sr.json": "ff102c60bff4773c3c2e37ce8d699c21",
"webapp-backup-20250805-040114/assets/data/debug_page_19.txt": "98c512ada4c0a7d90b8bfa60c4d16fbd",
"webapp-backup-20250805-040114/assets/data/rulebook_en.pdf": "386c5d9acd199ce11327b0119f369a3a",
"webapp-backup-20250805-040114/assets/data/rulebook_ja.pdf": "c8b8af88d9e497e4be085b102eeef1fa",
"webapp-backup-20250805-040114/assets/data/rulebook_ja_summary.md": "9ce3dc8de0f061d75593184637441c20",
"webapp-backup-20250805-040114/assets/data/connection_rules_ja.txt": "479a213c1dcaa624c83b75f79d6a77a8",
"webapp-backup-20250805-040114/assets/data/ai_implementation_guide.md": "7ee11ffc1eadd872fa862a27222d4382",
"webapp-backup-20250805-040114/assets/data/skills_fx.json": "fd9a38489b2a25e70975b90f2a0738a7",
"webapp-backup-20250805-040114/assets/data/d_score_master_knowledge.md": "f3b889a2b180c85a2e6da5305816c33e",
"webapp-backup-20250805-040114/assets/data/skills_ph.json": "5c6a409395dc29d31485043dafd89792",
"webapp-backup-20250805-040114/assets/data/difficulty_calculation_system.md": "11354eeca0f8b31d7a2c3a6dde2e22b5",
"webapp-backup-20250805-040114/assets/data/skills_en.csv": "c19de33e8f9ebf21d17c5148d1c1b3c6",
"webapp-backup-20250805-040114/assets/data/skills_ja.csv": "5cd2354bac160f6cad644d3264dcbde6",
"webapp-backup-20250805-040114/assets/data/rulebook_ja_full.txt": "c9e72ebbe2e6890f08119587893bf721",
"webapp-backup-20250805-040114/assets/data/apparatus_details.md": "13e4ac05fcf8f13907ba6be494aeed06",
"webapp-backup-20250805-040114/assets/data/comprehensive_rulebook_analysis.md": "73fa30eb4031a8c49f2b021f432111f1",
"webapp-backup-20250805-040114/assets/data/skills_difficulty_tables.md": "5cca84edf4ffd4db60908f7324ebab8d",
"webapp-backup-20250805-040114/assets/data/skills_pb.json": "348d97396187486e1e85fb053feeb0c1",
"webapp-backup-20250805-040114/assets/assets/logo.png": "ce2c8eb2a96e8d526b9826ca0716770d",
"webapp-backup-20250805-040114/canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"webapp-backup-20250805-040114/canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"webapp-backup-20250805-040114/canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"webapp-backup-20250805-040114/canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"webapp-backup-20250805-040114/canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"webapp-backup-20250805-040114/canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"webapp-backup-20250805-040114/canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"webapp-backup-20250805-040114/canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"webapp-backup-20250805-040114/canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"flutter_bootstrap.js": "295683d2c6ac509d888d1d51bdf90901",
"version.json": "b5d52a3eae84d49b4b5b74717cd65ed8",
"index.html": "d59d3c8f72830aded693eea4645d756a",
"/": "d59d3c8f72830aded693eea4645d756a",
"cache-bust.js": "4466fdcb93bf2bf057c06c455c18ba03",
"app_icon.png": "3f39380efa9064e9de32a0f53cc224dc",
"styles.css": "5c7aa437960978e90c95096fe8374a58",
"CNAME": "3e1b37ae5536711cce1294b461082260",
"DESIGN_PROTECTION_README.md": "bc1df7de9778edf0b106ad84607347fc",
"main.dart.js": "df31c76f983c7eb8065488c0af48d2a5",
"clear-cache.html": "b80044f111d10a2586d1efe83bd53847",
"simple_index_backup.html": "d9e032cfc211a1e96cb9009b7605d80b",
"terms.html": "8a40bb22174f8b7aa23dd018f0ba92df",
"webapp/flutter_bootstrap.js": "f233b917cca5669ff522cbe8e4448f90",
"webapp/version.json": "b5d52a3eae84d49b4b5b74717cd65ed8",
"webapp/index.html": "18f4824dbe70ee0a8e9c524887ac0d77",
"webapp/CNAME": "8ddf4b9f8e7ba866647e9a738d1a2225",
"webapp/main.dart.js": "3c373df32223c2e2fcb259ce8098f1ab",
"webapp/app_icon_new.png": "3f39380efa9064e9de32a0f53cc224dc",
"webapp/flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"webapp/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"webapp/icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"webapp/icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"webapp/icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"webapp/icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"webapp/manifest.json": "9863581815ecdce27aa6b22a719a945c",
"webapp/app_screenshot.png": "57a70f4ca9153cc14109b51c781fadd5",
"webapp/assets/AssetManifest.json": "dcbf689527d0cb649fe7aae52ae610e7",
"webapp/assets/NOTICES": "16be19a3048da70004d86b1298d548da",
"webapp/assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"webapp/assets/AssetManifest.bin.json": "32f229dc0ae013e5a86b5d8965a757c4",
"webapp/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"webapp/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"webapp/assets/AssetManifest.bin": "d82c224a6c220489bec5e37a1e183b77",
"webapp/assets/fonts/MaterialIcons-Regular.otf": "911780a8e7e9d114988df7fd0b8182c2",
"webapp/assets/data/skills_sr.json": "ff102c60bff4773c3c2e37ce8d699c21",
"webapp/assets/data/debug_page_19.txt": "98c512ada4c0a7d90b8bfa60c4d16fbd",
"webapp/assets/data/rulebook_en.pdf": "386c5d9acd199ce11327b0119f369a3a",
"webapp/assets/data/rulebook_ja.pdf": "c8b8af88d9e497e4be085b102eeef1fa",
"webapp/assets/data/rulebook_ja_summary.md": "9ce3dc8de0f061d75593184637441c20",
"webapp/assets/data/connection_rules_ja.txt": "479a213c1dcaa624c83b75f79d6a77a8",
"webapp/assets/data/ai_implementation_guide.md": "7ee11ffc1eadd872fa862a27222d4382",
"webapp/assets/data/skills_fx.json": "fd9a38489b2a25e70975b90f2a0738a7",
"webapp/assets/data/d_score_master_knowledge.md": "f3b889a2b180c85a2e6da5305816c33e",
"webapp/assets/data/skills_ph.json": "5c6a409395dc29d31485043dafd89792",
"webapp/assets/data/difficulty_calculation_system.md": "11354eeca0f8b31d7a2c3a6dde2e22b5",
"webapp/assets/data/skills_en.csv": "c19de33e8f9ebf21d17c5148d1c1b3c6",
"webapp/assets/data/skills_ja.csv": "5cd2354bac160f6cad644d3264dcbde6",
"webapp/assets/data/rulebook_ja_full.txt": "c9e72ebbe2e6890f08119587893bf721",
"webapp/assets/data/apparatus_details.md": "13e4ac05fcf8f13907ba6be494aeed06",
"webapp/assets/data/comprehensive_rulebook_analysis.md": "73fa30eb4031a8c49f2b021f432111f1",
"webapp/assets/data/skills_difficulty_tables.md": "5cca84edf4ffd4db60908f7324ebab8d",
"webapp/assets/data/skills_pb.json": "348d97396187486e1e85fb053feeb0c1",
"webapp/assets/assets/logo.png": "ce2c8eb2a96e8d526b9826ca0716770d",
"webapp/canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"webapp/canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"webapp/canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"webapp/canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"webapp/canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"webapp/canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"webapp/canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"webapp/canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"webapp/canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"cache-clear.html": "1e90882f0a8452bf871d5e7b6d7f3aad",
"testflight_subscription_setup.md": "4dcca6e9bf81b6b81ff145a4e866d1cd",
"deploy-trigger.txt": "f2512a0c49ff79279e9892684576acb2",
"webapp-old/flutter_bootstrap.js": "c505aa4dccb091b27ae4409e942bbf6a",
"webapp-old/version.json": "b5d52a3eae84d49b4b5b74717cd65ed8",
"webapp-old/index.html": "18f4824dbe70ee0a8e9c524887ac0d77",
"webapp-old/main.dart.js": "d8382e8f0aad6100c37159d32e145702",
"webapp-old/flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"webapp-old/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"webapp-old/icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"webapp-old/icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"webapp-old/icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"webapp-old/icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"webapp-old/manifest.json": "9863581815ecdce27aa6b22a719a945c",
"webapp-old/assets/AssetManifest.json": "dcbf689527d0cb649fe7aae52ae610e7",
"webapp-old/assets/NOTICES": "16be19a3048da70004d86b1298d548da",
"webapp-old/assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"webapp-old/assets/AssetManifest.bin.json": "32f229dc0ae013e5a86b5d8965a757c4",
"webapp-old/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"webapp-old/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"webapp-old/assets/AssetManifest.bin": "d82c224a6c220489bec5e37a1e183b77",
"webapp-old/assets/fonts/MaterialIcons-Regular.otf": "911780a8e7e9d114988df7fd0b8182c2",
"webapp-old/assets/data/skills_sr.json": "ff102c60bff4773c3c2e37ce8d699c21",
"webapp-old/assets/data/debug_page_19.txt": "98c512ada4c0a7d90b8bfa60c4d16fbd",
"webapp-old/assets/data/rulebook_en.pdf": "386c5d9acd199ce11327b0119f369a3a",
"webapp-old/assets/data/rulebook_ja.pdf": "c8b8af88d9e497e4be085b102eeef1fa",
"webapp-old/assets/data/rulebook_ja_summary.md": "9ce3dc8de0f061d75593184637441c20",
"webapp-old/assets/data/connection_rules_ja.txt": "479a213c1dcaa624c83b75f79d6a77a8",
"webapp-old/assets/data/ai_implementation_guide.md": "7ee11ffc1eadd872fa862a27222d4382",
"webapp-old/assets/data/skills_fx.json": "fd9a38489b2a25e70975b90f2a0738a7",
"webapp-old/assets/data/d_score_master_knowledge.md": "f3b889a2b180c85a2e6da5305816c33e",
"webapp-old/assets/data/skills_ph.json": "5c6a409395dc29d31485043dafd89792",
"webapp-old/assets/data/difficulty_calculation_system.md": "11354eeca0f8b31d7a2c3a6dde2e22b5",
"webapp-old/assets/data/skills_en.csv": "c19de33e8f9ebf21d17c5148d1c1b3c6",
"webapp-old/assets/data/skills_ja.csv": "5cd2354bac160f6cad644d3264dcbde6",
"webapp-old/assets/data/rulebook_ja_full.txt": "c9e72ebbe2e6890f08119587893bf721",
"webapp-old/assets/data/apparatus_details.md": "13e4ac05fcf8f13907ba6be494aeed06",
"webapp-old/assets/data/comprehensive_rulebook_analysis.md": "73fa30eb4031a8c49f2b021f432111f1",
"webapp-old/assets/data/skills_difficulty_tables.md": "5cca84edf4ffd4db60908f7324ebab8d",
"webapp-old/assets/data/skills_pb.json": "348d97396187486e1e85fb053feeb0c1",
"webapp-old/assets/assets/logo.png": "ce2c8eb2a96e8d526b9826ca0716770d",
"webapp-old/canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"webapp-old/canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"webapp-old/canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"webapp-old/canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"webapp-old/canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"webapp-old/canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"webapp-old/canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"webapp-old/canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"webapp-old/canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"mobile.html": "c03a0d46e45bb9a165edf7ea793bc8f3",
"deploy-timestamp.txt": "d1a46254f4e8231efdb2ec5181e7d736",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"test.html": "fb4a6bae5e5fb6df770b213965607dcc",
"legal-styles.css": "080675c491727c4f2d04d7cb64f7a87c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "9863581815ecdce27aa6b22a719a945c",
"app_screenshot.png": "57a70f4ca9153cc14109b51c781fadd5",
"app.html": "417442171b7965a0d729e87f593ef352",
"assets/AssetManifest.json": "5039a6c29aa6d936649c7f2ef46a2133",
"assets/NOTICES": "16be19a3048da70004d86b1298d548da",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "cdb2277e8c5fb4d6d54d17fb0edcca61",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "d6900462b537f23014d8dc0bdce57dbe",
"assets/fonts/MaterialIcons-Regular.otf": "1ba2cf4859836b699861e2f146975a1f",
"assets/data/skills_sr.json": "ff102c60bff4773c3c2e37ce8d699c21",
"assets/data/debug_page_19.txt": "98c512ada4c0a7d90b8bfa60c4d16fbd",
"assets/data/rulebook_en.pdf": "386c5d9acd199ce11327b0119f369a3a",
"assets/data/rulebook_ja.pdf": "c8b8af88d9e497e4be085b102eeef1fa",
"assets/data/rulebook_ja_summary.md": "9ce3dc8de0f061d75593184637441c20",
"assets/data/connection_rules_ja.txt": "479a213c1dcaa624c83b75f79d6a77a8",
"assets/data/ai_implementation_guide.md": "7ee11ffc1eadd872fa862a27222d4382",
"assets/data/skills_fx.json": "fd9a38489b2a25e70975b90f2a0738a7",
"assets/data/d_score_master_knowledge.md": "f3b889a2b180c85a2e6da5305816c33e",
"assets/data/skills_ph.json": "5c6a409395dc29d31485043dafd89792",
"assets/data/difficulty_calculation_system.md": "11354eeca0f8b31d7a2c3a6dde2e22b5",
"assets/data/skills_en.csv": "c19de33e8f9ebf21d17c5148d1c1b3c6",
"assets/data/skills_ja.csv": "a4bc7102fb96eb33a302593b7cec2aa9",
"assets/data/rulebook_ja_full.txt": "c9e72ebbe2e6890f08119587893bf721",
"assets/data/apparatus_details.md": "13e4ac05fcf8f13907ba6be494aeed06",
"assets/data/comprehensive_rulebook_analysis.md": "73fa30eb4031a8c49f2b021f432111f1",
"assets/data/skills_difficulty_tables.md": "5cca84edf4ffd4db60908f7324ebab8d",
"assets/data/skills_pb.json": "348d97396187486e1e85fb053feeb0c1",
"assets/assets/logo.png": "ce2c8eb2a96e8d526b9826ca0716770d",
"server.log": "efbf42e996f202aa7c12c12b555cc5e8",
"PREMIUM_LANDING_PAGE_BACKUP.html": "53448ec5ac43288bb9fc8f4f0e59b21e",
"privacy.html": "78b6da6410d4355cb5a3adc443eac09e",
"force-update.html": "4cc44bed55001b576464f27354c474f3",
"old_index.html": "d9e032cfc211a1e96cb9009b7605d80b",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
