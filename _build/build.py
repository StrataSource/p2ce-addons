import os
import shutil
import sys

from sourcepp import vpkpp


def build_addon(addon_dir: str, output_dir_parent: str) -> None:
    output_dir = os.path.join(output_dir_parent, "p2ce_" + os.path.basename(addon_dir))
    os.makedirs(output_dir, exist_ok=True)
    print(f"Building addon {os.path.basename(addon_dir)} to {os.path.relpath(output_dir, os.getcwd())}")

    to_pack: list[str] = []
    for content_entry_name in os.listdir(addon_dir):
        content_entry_path = os.path.join(addon_dir, content_entry_name)
        if content_entry_name.startswith('.') or content_entry_name == "addon.kv3" or content_entry_name == "media":
            # We can't pack media yet. Remove that check when this is no longer the case
            print(f"Copying {content_entry_name}")
            if os.path.isdir(content_entry_path):
                shutil.copytree(content_entry_path, os.path.join(output_dir, content_entry_name), dirs_exist_ok=True)
            else:
                shutil.copy(content_entry_path, output_dir)
            continue

        print(f"Packing {content_entry_name}")
        to_pack.append(content_entry_path)

    if len(to_pack) > 0:
        vpk = vpkpp.VPK.create(os.path.join(output_dir, "pak01_dir.vpk"))
        for entry in to_pack:
            if os.path.isdir(entry):
                vpk.add_directory(os.path.basename(entry), entry)
            elif os.path.isfile(entry):
                vpk.add_entry_from_file(os.path.basename(entry), entry)
        vpk.bake()


def zip_addons(parent_dir: str, stem: str) -> None:
    print(f"Zipping contents of {parent_dir} into {stem}.zip")
    shutil.make_archive(os.path.join(parent_dir, stem), "zip", parent_dir)


def build(addon_root_dir: str) -> None:
    output_dir_parent = os.path.join(addon_root_dir, "_out")

    addon_count = 0
    for addon_dir_name in os.listdir(addon_root_dir):
        if addon_dir_name.startswith(('.', '_')):
            continue
        addon_dir = os.path.join(addon_root_dir, addon_dir_name)
        if not os.path.isdir(addon_dir):
            continue
        build_addon(addon_dir, output_dir_parent)
        addon_count += 1

    zip_addons(output_dir_parent, "addons")
    print(f"Completed, built {addon_count} addons")


if __name__ == "__main__":
    build(os.path.realpath(os.path.join(os.path.dirname(__file__), os.path.pardir)) if len(sys.argv) < 2 else sys.argv[1])
