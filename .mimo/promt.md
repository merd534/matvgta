You are an expert Godot 4.x (GDScript) game developer and systems architect. We are building an ambitious 3D Immersive Sim / Stealth Open-World game named "MatvGTA" from a first/third-person perspective. The visual style is a vibrant, neon-colored metropolis with highly contrastive lighting, featuring simulated living city elements similar to "Shadows of Doubt".

CRITICAL RULE: You must work STRICTLY PHASE BY PHASE. Do NOT write code for subsequent phases until I explicitly approve the current phase. Start by generating only Phase 1. 

Here is the complete blueprint of the 7-Phase development pipeline:

### PHASE 1: 3D Architecture & Multi-Story Procedural City Generator
1. GridMap or CSG/Scene-based procedural generator (`WorldGenerator3D.gd`).
2. World size selector before start: Small, Medium, Large, Extra Large, Giant (define proper grid dimensions in chunks).
3. Zoning: Regular colorful neon districts and Wealthy districts (taller buildings, complex penthouse structures, denser security).
4. Verticality: Multi-story buildings where EVERY floor is fully functional, containing rooms, furniture, and doors.
5. 3D Ventilation Network: Procedurally generate hollow ventilation shafts inside walls/ceilings connecting rooms, different floors, and streets, which the player can crawl through.
6. Auto-bake 3D Navigation Region (`NavigationRegion3D`) dynamically so AI can traverse the generated city.

### PHASE 2: 3D Stealth Physics, Dynamic Lighting & Vent Highlighting
1. Player Controller (`Player3D.gd`) with First/Third-person physics supporting Idle, Walk, Run, and Crouch states.
2. 3D Light-Based Stealth: Use RayCast3D or local OmniLight3D/SpotLight3D evaluation to calculate player exposure to light. If in deep shadow and crouching, player visibility drops to zero.
3. Sound/Noise Radius: Walking/crouching emits zero noise. Running expands a noise sphere that alerts nearby guards.
4. Vent Evacuation Highlight: When entering any building, all ventilation grates/hatches on the current floor dynamically light up (via Material Emission or custom outline shader). Player can enter vents, dropping visibility to zero.
5. Random Loot System (`LootSpawner3D.gd`): Containers (safes, desks) filled with randomized loot. Wealthy zones have high-tier loot but require electronic hacking.

### PHASE 3: Security Systems, Guard AI & Hacker Gadgets
1. 3D Security Cameras (`SecurityCamera.gd`): Rotational Node3D with a physical vision cone (Area3D + RayCast3D). Spotting the player triggers local Alarm state, turning the cone red and attracting guards.
2. System Hacking: Security terminals to temporarily disable all cameras on the floor via a timer.
3. Infiltration Gadgets: A portable EMP/hacking device that creates a 4-meter metric sphere upon activation, knocking out all cameras inside it for 30 seconds.
4. Pickpocketing: Ability to approach civilian NPCs from behind in stealth to steal their personal loot based on success rate checks.

### PHASE 4: Dialogue System, Asset Loader, Graphics Presets & Dynamic Audio
1. 3D Dialogue System: Branching conversations allowing player to bribe employees or deceive building owners (e.g., impersonating a sanitary inspector, checking charisma/fake IDs in inventory).
2. Asset Loading Modes: 
   - Mode A (Web/Internet): Templates using HTTPRequest to stream free .gltf/.glb models and sounds via URLs.
   - Mode B (Procedural): FastNoiseLite texture generation, ArrayMesh/CSG mesh synthesis, and runtime audio generation via AudioStreamGenerator.
3. Deep 3D Graphics Settings (`SettingsManager3D.gd`): 4 Presets using RenderingServer/Viewport:
   - "Potato Mode": <50% 3D resolution scale, disabled shadows, MSAA, SSAO, and rendering distance.
   - Low / Medium / High presets.
   - "Ultra Mode": Maximum chunk render distance, MSAA 4x/8x, 16x Anisotropic filtering, High-Res soft shadows, SSAO, SSR, and SDFGI (Screen-Space Global Illumination).
4. Dynamic 3D Audio: Seamless transition between atmospheric neon jazz (exploration) and intense electronic beats (alarm/chase).

### PHASE 5: Living City Simulation, Police Patrols & Black Market Economy
1. Citizen AI Life Cycle: NPCs have individual daily routines. They leave apartments, walk/drive to work (offices/restaurants), return home, and sleep. Player can stalk wealthy targets to rob empty homes.
2. Wanted System & Police AI (`PoliceDirector3D.gd`): 1-5 star system. Committing crimes or camera alerts spawns police officers/vehicles. Police aggressively search backalleys and vents if they witness the player entering.
3. Black Market Fence NPC: Hidden vendor to sell stolen electronics, jewelry, documents, or blackmail files. Dynamic pricing economy. Cash is used to buy advanced lockpicks and high-tier EMP devices.
4. Procedural Clues: Finding sensitive blackmail documents in wealthy safes to extort NPCs via the dialogue system.

### PHASE 6: Main Menu, Player HUD, Inventory & Save/Load System
1. Main Menu UI: Vibrant neon interface with New Game (size select), Settings (presets), Load Game, and Exit buttons.
2. Player HUD: Health bar, stamina bar, stealth/noise meter, wallet, wanted stars, and contextual notification banner.
3. Inventory Management: Tab-menu displaying item grid, loot value, and equipped gadgets.
4. Save/Load Engine (`SaveSystem.gd`): Serialize world seed, player coordinates, inventory array, money, and faction/NPC states into a ConfigFile/JSON format.
5. Programmatic Auto-Builder (`MainScene.gd`): A root node manager script that initializes the entire hierarchy and hooks up all scripts chronologically to prevent null references.

### PHASE 7: Performance Optimization, Mesh Merging & Stability Polish
1. Chunk Mesh Merging: Optimize performance by combining static building meshes and collision shapes inside a chunk using MultiMeshInstance3D or runtime CSG baking to maintain high FPS.
2. Asynchronous Navigation Baking: Multi-threaded execution of `NavigationServer3D.region_bake_navigation_mesh()` to avoid lag spikes during city generation.
3. Cyclic Dependency Resolution: Audit and strip out direct cross-referencing `class_name` definitions, replacing them with safe dynamic Node calls or Autoload Singletons.
4. Race Condition Fixes: Enforce a strict chronological initialization flow (Generator -> Player -> Simulation -> UI) inside `MainScene.gd` to eliminate `_ready()` race condition crashes.

---

CURRENT OBJECTIVE: Begin with PHASE 1 ONLY. Write clean, modular, and optimized Godot 4.2+ GDScript for the 3D Procedural City Generator. Design the folder structure logically (e.g., `res://scripts/world/`, `res://scripts/player/`). Do not write UI or Player code yet. Provide the full code for `WorldGenerator3D.gd` and explain how the chunk/multi-story logic works.  игра должна поддерживать 2 языка английский и русский. русский по умолчанию
