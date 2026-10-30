"""Runs the JPEXS decompiler, which renders the frames of SWF symbols to PNG files."""

import os
import shutil
import subprocess


def run_jpexs(jpexs, swf_path, selection, work_dir):
	"Renders every frame of the selected sprites to PNG in work_dir, one folder for each sprite."
	command = ["java", "-jar", jpexs] if jpexs.endswith(".jar") else [jpexs]
	command += selection + ["-format", "sprite:png", "-export", "sprite", work_dir, swf_path]
	result = subprocess.run(command, capture_output=True, text=True)
	if result.returncode != 0:
		raise RuntimeError(f"JPEXS failed for {swf_path}: {result.stdout[-500:]}{result.stderr[-500:]}")


def exported_frames(work_dir, matches, what):
	"Returns the frame files of the one exported folder whose name matches, in order."
	folders = [d for d in os.listdir(work_dir) if matches(d)]
	if len(folders) != 1:
		raise RuntimeError(f"JPEXS did not export {what}")
	folder = os.path.join(work_dir, folders[0])
	frames = sorted((f for f in os.listdir(folder) if f.endswith(".png")), key=lambda f: int(f[:-4]))
	return [os.path.join(folder, f) for f in frames]


def copy_frames(frames, folder):
	os.makedirs(folder, exist_ok=True)
	for index, frame in enumerate(frames, start=1):
		shutil.copyfile(frame, os.path.join(folder, f"{index}.png"))
