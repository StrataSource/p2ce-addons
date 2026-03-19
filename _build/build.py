import os
import shutil
import sys

from PIL import Image
from sourcepp import vpkpp


# Excluded from packing
PATH_PACK_FILTER = (
    "/.assets/",
    "/media/",
    "/addon.kv3",
    "/scripts/campaigns.kv3",
)


def add_overlay_to_image(base_path: str, overlay_path: str, out_path: str) -> None:
    base = Image.open(base_path).convert("RGBA")
    overlay = Image.open(overlay_path).convert("RGBA")
    base = base.resize(overlay.size, Image.Resampling.BICUBIC)
    base.paste(overlay, None, overlay)
    base.convert("RGB").save(out_path)


def create_pack_list(addon_dir: str, partial_dir: str, to_pack: list[str], to_copy: list[str]):
    path = addon_dir + partial_dir
    for content_entry_name in os.listdir(path):
        content_entry_path = os.path.join(path, content_entry_name)
        content_partial_path = partial_dir + "/" + content_entry_name
        if os.path.isdir(content_entry_path):
            create_pack_list(addon_dir, content_partial_path , to_pack, to_copy)
        else:
            if content_partial_path.startswith(PATH_PACK_FILTER):
                to_copy.append(content_partial_path)
                continue
            to_pack.append(content_partial_path)


def build_addon(addon_dir: str, output_dir_parent: str) -> None:
    output_dir = os.path.join(output_dir_parent, "p2ce_" + os.path.basename(addon_dir))
    os.makedirs(output_dir, exist_ok=True)
    print(f"\nBuilding addon {os.path.basename(addon_dir)} to {os.path.relpath(output_dir, os.getcwd())}")

    to_pack: list[str] = []
    to_copy: list[str] = []

    create_pack_list(addon_dir, "", to_pack, to_copy)

    for entry in to_copy:
        print(f"Copying \"{entry}\"")
        dirname = os.path.dirname(entry)
        os.makedirs(output_dir + dirname, exist_ok=True)
        shutil.copy(addon_dir + entry, output_dir + entry)

    if len(to_pack) > 0:
        vpk = vpkpp.VPK.create(os.path.join(output_dir, "pak01_dir.vpk"))
        for entry in to_pack:
            print(f"Packing \"{entry}\"")
            vpk.add_entry_from_file(entry, addon_dir + entry)
        vpk.bake()

    if (
        os.path.exists(thumb_path := os.path.join(output_dir, ".assets", "thumb.png")) or
        os.path.exists(thumb_path := os.path.join(output_dir, ".assets", "thumb.jpg")) or
        os.path.exists(thumb_path := os.path.join(output_dir, ".assets", "thumb.jpeg"))
    ):
        add_overlay_to_image(thumb_path, os.path.join(os.path.dirname(__file__), "assets", "thumb_overlay.png"), thumb_path)


def zip_addons(parent_dir: str, stem: str) -> None:
    print(f"Zipping contents of {parent_dir} into {stem}.zip")
    shutil.make_archive(os.path.join(parent_dir, os.path.pardir, stem), "zip", parent_dir)


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
