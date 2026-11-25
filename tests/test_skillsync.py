import importlib.machinery
import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLSYNC_PATH = REPO_ROOT / "modules" / "antigravity" / "user" / ".local" / "bin" / "skillsync"


def load_skillsync():
    loader = importlib.machinery.SourceFileLoader("skillsync_mod", str(SKILLSYNC_PATH))
    spec = importlib.util.spec_from_loader("skillsync_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def test_parse_and_classify_mattpocock_skills(tmp_path):
    mod = load_skillsync()
    tree = [
        {"type": "tree", "path": "skills/engineering/tdd", "sha": "sha_tdd"},
        {"type": "blob", "path": "skills/engineering/tdd/SKILL.md", "sha": "b1"},
        {"type": "tree", "path": "skills/productivity/grilling", "sha": "sha_grill_v2"},
        {"type": "blob", "path": "skills/productivity/grilling/SKILL.md", "sha": "b2"},
        {"type": "tree", "path": "skills/deprecated/old-skill", "sha": "sha_old"},
        {"type": "blob", "path": "skills/deprecated/old-skill/SKILL.md", "sha": "b3"},
        {"type": "tree", "path": "skills/in-progress/loop-me", "sha": "sha_loop"},
        {"type": "blob", "path": "skills/in-progress/loop-me/SKILL.md", "sha": "b4"},
    ]
    upstream = mod.parse_mattpocock_tree(tree)
    assert set(upstream.keys()) == {"tdd", "grilling", "old-skill", "loop-me"}
    assert upstream["tdd"]["tree_sha"] == "sha_tdd"

    skills_root = tmp_path / "skills"
    (skills_root / "grilling").mkdir(parents=True)
    (skills_root / "grilling" / "SKILL.md").write_text("old", encoding="utf-8")
    (skills_root / "old-skill").mkdir(parents=True)
    (skills_root / "old-skill" / "SKILL.md").write_text("dep", encoding="utf-8")

    manifest = {
        "mattpocock": {
            "grilling": {"tree_sha": "sha_grill_v1"},
            "old-skill": {"tree_sha": "sha_old"},
        },
        "excluded": [],
    }
    report = mod.classify_mattpocock_skills(upstream, skills_root, manifest, include_in_progress=False)
    assert [m["name"] for m in report["new"]] == ["tdd"]
    assert [m["name"] for m in report["update"]] == ["grilling"]
    assert [m["name"] for m in report["deprecated"]] == ["old-skill"]


def test_ecc_trimmed_within_budget():
    ecc_dir = REPO_ROOT / "modules" / "antigravity" / "user" / ".gemini" / "config" / "plugins" / "ecc"
    agents = list((ecc_dir / "agents").glob("*.md"))
    ecc_skills = [p for p in (ecc_dir / "skills").iterdir() if p.is_dir()]
    rules = list((ecc_dir / "rules").glob("*.md"))
    assert len(agents) <= 30
    assert len(ecc_skills) <= 55
    assert len(rules) <= 45
    assert (ecc_dir / "rules" / "common-cross-os-sync.md").is_file()
