import json
import re
import httpx
from config import settings


async def check_available() -> bool:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{settings.ollama_base_url}/api/tags")
            return r.status_code == 200
    except Exception:
        return False


async def generate(prompt: str, system: str = "") -> str:
    payload = {
        "model": settings.ollama_model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.8, "num_predict": 4096},
    }
    if system:
        payload["system"] = system

    async with httpx.AsyncClient(timeout=settings.ollama_timeout) as client:
        r = await client.post(f"{settings.ollama_base_url}/api/generate", json=payload)
        r.raise_for_status()
        return r.json()["response"]


SCRIPT_SYSTEM = """You are a professional cinematic scriptwriter and story analyst.
Your output must always be valid, well-structured cinematic scripts.
Include: narration, dialogue, camera directions, lighting descriptions, mood, sound cues,
scene descriptions, character actions, object/prop references, and location references.
Support both English and Arabic content when requested.
Format scripts in industry-standard screenplay format."""

SCENE_SYSTEM = """You are a professional film director and story analyst.
Break stories into precise scenes and shots.
Return your response as valid JSON only, with no extra commentary.
Each scene has: scene_number, title, description, location, mood, time_of_day.
Each shot has: shot_number, description, duration_preset, camera_movement, lighting, mood,
style, characters, objects, audio_cues, location, suggested_prompt."""

BIBLE_SYSTEM = """You are a professional story bible writer.
Create comprehensive, detailed story bibles that maintain continuity across a production.
Return your response as valid JSON only."""


async def generate_script(prompt: str, language: str = "english") -> str:
    lang_note = ""
    if language == "arabic":
        lang_note = "Write the script entirely in Arabic."
    elif language == "bilingual":
        lang_note = "Write the script in both English and Arabic (bilingual format)."

    user_prompt = f"""Create a full cinematic script for the following story:

{prompt}

{lang_note}

Include:
1. TITLE PAGE
2. NARRATIVE SUMMARY (2-3 sentences)
3. VISUAL STYLE RECOMMENDATION
4. FULL SCRIPT with:
   - Scene headings (INT./EXT. LOCATION - DAY/NIGHT)
   - Action lines (what we see)
   - Character dialogue with voice/tone notes
   - Camera directions (CLOSE ON, WIDE SHOT, PAN TO, etc.)
   - Lighting descriptions
   - Sound cues and music suggestions
   - Mood/atmosphere descriptions
   - Object and prop references
5. SCENE OUTLINE (numbered list of scenes)

Make it cinematic, dramatic, and suitable for a short highlight video (20–90 seconds total).
"""
    return await generate(user_prompt, SCRIPT_SYSTEM)


async def generate_scene_breakdown(script: str, prompt: str) -> dict:
    user_prompt = f"""Given this story and script, generate a detailed scene and shot breakdown.

STORY PROMPT:
{prompt}

SCRIPT:
{script[:3000]}

Return ONLY a JSON object with this exact structure:
{{
  "scenes": [
    {{
      "scene_number": 1,
      "title": "Scene title",
      "description": "What happens in this scene",
      "location": "Where it takes place",
      "mood": "emotional mood",
      "time_of_day": "day/night/dusk/dawn",
      "shots": [
        {{
          "shot_number": 1,
          "description": "What the camera sees",
          "duration_preset": "standard_cinematic",
          "camera_movement": "SLOW PUSH IN / STATIC / PAN RIGHT / etc",
          "lighting": "natural daylight / dramatic shadows / etc",
          "mood": "tense / peaceful / etc",
          "style": "cinematic / documentary / etc",
          "characters": ["Character Name"],
          "objects": ["Object name"],
          "audio_cues": "ambient sound or music note",
          "location": "specific location",
          "suggested_prompt": "detailed image generation prompt for this shot"
        }}
      ]
    }}
  ],
  "visual_style_recommendation": "overall visual style"
}}
"""
    response = await generate(user_prompt, SCENE_SYSTEM)
    try:
        json_match = re.search(r'\{[\s\S]*\}', response)
        if json_match:
            return json.loads(json_match.group())
    except (json.JSONDecodeError, AttributeError):
        pass
    return {"scenes": [], "visual_style_recommendation": "cinematic", "error": "parse_failed", "raw": response}


async def generate_story_bible(prompt: str, script: str, characters: list, locations: list) -> dict:
    char_str = "\n".join([f"- {c}" for c in characters]) if characters else "None defined yet"
    loc_str = "\n".join([f"- {l}" for l in locations]) if locations else "None defined yet"

    user_prompt = f"""Create a comprehensive story bible for this production.

STORY PROMPT:
{prompt}

SCRIPT EXCERPT:
{script[:2000]}

CHARACTERS: {char_str}
LOCATIONS: {loc_str}

Return ONLY a JSON object:
{{
  "title": "Project title",
  "genre": "genre",
  "tone": "tone description",
  "visual_style": "visual style description",
  "narrative_summary": "2-3 sentence summary",
  "main_themes": ["theme1", "theme2"],
  "character_arcs": {{"CharacterName": "arc description"}},
  "timeline": ["event 1", "event 2"],
  "important_events": ["key event 1", "key event 2"],
  "voice_narration_style": "narration style description",
  "continuity_rules": ["rule 1", "rule 2"],
  "approved_visual_refs": ["reference style 1"],
  "approved_prompt_rules": ["always include X", "never show Y"]
}}
"""
    response = await generate(user_prompt, BIBLE_SYSTEM)
    try:
        json_match = re.search(r'\{[\s\S]*\}', response)
        if json_match:
            return json.loads(json_match.group())
    except (json.JSONDecodeError, AttributeError):
        pass
    return {"error": "parse_failed", "raw": response}


async def generate_shots_for_scene(
    scene_title: str,
    scene_description: str,
    location: str,
    mood: str,
    story_prompt: str,
) -> dict:
    user_prompt = f"""You are a cinematographer. Generate 3-5 camera shots for this scene.

SCENE: {scene_title}
DESCRIPTION: {scene_description}
LOCATION: {location}
MOOD: {mood}
STORY: {story_prompt[:500]}

Return ONLY a JSON object like this (no other text):
{{
  "shots": [
    {{
      "shot_number": 1,
      "description": "What the camera sees",
      "duration_preset": "standard_cinematic",
      "camera_movement": "SLOW PUSH IN",
      "lighting": "natural daylight",
      "mood": "tense",
      "style": "cinematic",
      "characters": [],
      "objects": [],
      "audio_cues": "ambient sound",
      "location": "{location}",
      "suggested_prompt": "detailed stable diffusion prompt for this shot"
    }}
  ]
}}

duration_preset must be one of: fast_trailer, standard_cinematic, slow_dramatic, long_atmospheric"""

    response = await generate(user_prompt)
    try:
        json_match = re.search(r'\{[\s\S]*\}', response)
        if json_match:
            return json.loads(json_match.group())
    except (json.JSONDecodeError, AttributeError):
        pass
    return {"shots": [], "error": "parse_failed", "raw": response}


async def generate_storyboard_prompt(shot_description: str, style: str, characters: list, location: str) -> str:
    char_str = ", ".join(characters) if characters else "no specific characters"
    user_prompt = f"""Generate a detailed image generation prompt for this storyboard shot.

Shot description: {shot_description}
Visual style: {style or "cinematic, dramatic"}
Characters: {char_str}
Location: {location or "unspecified"}

Write a single detailed prompt (150-250 words) suitable for Stable Diffusion.
Include: composition, lighting, color palette, atmosphere, character details, background, camera angle.
Start with the most important visual elements.
End with technical quality terms like: cinematic, high detail, 8k, professional photography.
Return ONLY the prompt text, no explanation."""
    return await generate(user_prompt)
