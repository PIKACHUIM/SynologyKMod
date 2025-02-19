import json
import os
import time
import urllib.request


def fetch_kmod(in_name):
    with open(in_name, 'r') as read_file:
        read_data = json.loads(read_file.read())
    mods_nums = 0
    save_json = {}
    for kern_name in read_data:
        save_path = "KernModule/%s" % kern_name
        save_json[kern_name] = {}
        if not os.path.exists(save_path):
            os.mkdir(save_path)
        for mods_name in read_data[kern_name]:
            mods_text = read_data[kern_name][mods_name]
            mods_nums += 1
            mods_urls = "https://mi-d.cn/d/modules/%s/%s.ko" % (kern_name, mods_name)
            save_path = "KernModule/%s/%s.ko" % (kern_name, mods_name)
            try:
                urllib.request.urlretrieve(mods_urls, save_path)
                save_json[kern_name][mods_name] = mods_text
                print("下载完成：", "%04d" % mods_nums, kern_name, mods_name)
                time.sleep(0.1)
            except Exception as e:
                print("下载失败：", "%04d" % mods_nums, kern_name, mods_name)
        with open("SaveModule.json", 'w') as write_file:
            write_file.write(json.dumps(save_json))


if __name__ == '__main__':
    fetch_kmod("KernModule.json")
