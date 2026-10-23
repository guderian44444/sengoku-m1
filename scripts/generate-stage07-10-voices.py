"""Author original Japanese stage 7-10 entrances with the existing local VoiceDesign pipeline."""
import importlib.util, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("voice_pipeline",ROOT/"scripts/generate-voices-v15.py")
voice=importlib.util.module_from_spec(spec);spec.loader.exec_module(voice)
voice.OUT=ROOT/"game/audio/stages07-10";voice.OUT.mkdir(parents=True,exist_ok=True)
voice.CACHE=ROOT/"artifacts/stages07-10-revision-20261023/voices";voice.CACHE.mkdir(parents=True,exist_ok=True)
voice.KEY_TAG="expedition";voice.MAX_ATTEMPTS=3
jobs=[
(7,"ujie","氏家直元（卜全）","氏家卜全、参る！美濃の山道は渡さぬ！","氏家卜全在此！美濃山道，休想通過！","Rugged brisk middle-aged Japanese male spearman with a sharp gritty baritone."),
(7,"inaba","稻葉良通（一鐵）","稲葉一鉄、ここにあり！その覚悟、刀で示せ！","稻葉一鐵在此！有何覺悟，用刀證明！","Older Japanese male general, deep gravelly stern bass with strong chest resonance."),
(8,"nagai","長井道利","城門を守れ！長井道利が相手だ！","守住城門！長井道利奉陪！","Mature Japanese male gun captain, dry cutting mid-low voice."),
(8,"tatsuoki","齋藤龍興","斎藤龍興、見参！稲葉山の誇り、見せてやる！","齋藤龍興在此！見識稻葉山的傲骨！","Young adult Japanese male daimyo, bright proud clear tenor-baritone."),
(9,"nagayasu","三好長逸","三好長逸、参る！街道の先へは行かせぬ！","三好長逸出陣！此路不通！","Mature Japanese male strategist, clipped firm authoritative baritone."),
(9,"iwanari","岩成友通","岩成友通、推参！我が薙刀を越えてみよ！","岩成友通在此！有膽便越過我的薙刀！","Strong adult Japanese male polearm warrior, bold rough low voice."),
(10,"kagetsune","朝倉景恒","朝倉景恒、出る！退く敵を逃がすな！","朝倉景恒出陣！休讓敵軍逃走！","Japanese male armored captain, precise ringing mature baritone."),
(10,"yoshikage","朝倉義景","朝倉義景である！越前の兵よ、退路を断て！","朝倉義景在此！越前將士，截斷退路！","Mature Japanese male daimyo, dignified powerful resonant bass-baritone.")]
manifest={"version":"1","backend":"Original local Qwen3 VoiceDesign; no voice cloning","listening_review":"pending human audition","clips":{},"stage_boss_intros":{}}
ffmpeg=voice.ffmpeg_executable()
for stage,role,name,text,subtitle,tone in jobs:
    delivery=tone+" Project a fierce voiced Japanese arcade battlefield challenge, complete sentence, clear consonants, energetic chest-supported proclamation. No narration, whisper, music or sound effects. Under six seconds."
    _,clip=voice.make_clip(ffmpeg,(role,"intro",0,text,delivery,False,subtitle))
    key=f"s{stage:02d}_{role}_intro"
    clip["file"]="res://audio/stages07-10/"+clip["file"]
    clip["category"]="boss_intro"
    manifest["clips"][key]=clip
    manifest["stage_boss_intros"][name]={"name":name,"line_key":key,"text":text,"subtitle":subtitle,"ticks":max(150,math.ceil(clip["seconds"]*60)+24)}
    voice.write_json(voice.OUT/"manifest.json",manifest)
    print("VOICE_READY",key,clip["seconds"],flush=True)
print("EXPEDITION_VOICES_PASS",len(manifest["clips"]),flush=True)
