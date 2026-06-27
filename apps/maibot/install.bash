#!/usr/bin/env bash
# ===========================================================================
# MaiBot 1Panel 应用安装 / 更新脚本
#
# 用法:
#   install.bash              # 安装（等同于 install.bash install）
#   install.bash install      # 全新安装
#   install.bash update       # 更新到最新版本
#   install.bash --help       # 显示帮助信息
#
# 环境变量:
#   INSTALL_ROOT   自定义安装根目录（默认 /opt/1panel/resource/apps/local）
#   GITHUB_MIRROR  GitHub 镜像地址（用于加速下载，如 https://ghproxy.com）
# ===========================================================================

set -euo pipefail

# --- 常量 -------------------------------------------------------------------
readonly REPO_OWNER="Puiching-Memory"
readonly REPO_NAME="MaiBot-1Panel"
readonly REPO_BRANCH="MaiBot"
readonly APP_NAME="maibot"
readonly SCRIPT_VERSION="2.1.0"

INSTALL_ROOT="${INSTALL_ROOT:-/opt/1panel/resource/apps/local}"
GITHUB_MIRROR="${GITHUB_MIRROR:-}"
_TMP_DIR=""

# --- 颜色 -------------------------------------------------------------------
if [[ -t 1 ]]; then
	C_RED=$'\033[0;31m'
	C_GREEN=$'\033[0;32m'
	C_YELLOW=$'\033[0;33m'
	C_CYAN=$'\033[0;36m'
	C_BOLD=$'\033[1m'
	C_RESET=$'\033[0m'
else
	C_RED='' C_GREEN='' C_YELLOW='' C_CYAN='' C_BOLD='' C_RESET=''
fi

# --- 日志函数 ---------------------------------------------------------------
log()  { printf "%s %s\n" "${C_GREEN}[MaiBot]${C_RESET}" "$1"; }
info() { printf "%s %s\n" "${C_CYAN}[MaiBot]${C_RESET}" "$1"; }
warn() { printf "%s %s\n" "${C_YELLOW}[MaiBot 警告]${C_RESET}" "$1" >&2; }
fail() { printf "%s %s\n" "${C_RED}[MaiBot 错误]${C_RESET}" "$1" >&2; exit 1; }

# --- 工具函数 ---------------------------------------------------------------

# 检查命令是否可用
require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "未找到命令 '$1'，请先安装后再运行。"
}

# 获取下载工具
setup_downloader() {
	if command -v curl >/dev/null 2>&1; then
		DOWNLOAD_CMD=(curl -fsSL)
	elif command -v wget >/dev/null 2>&1; then
		DOWNLOAD_CMD=(wget -qO-)
	else
		fail '需要安装 curl 或 wget 以便从 GitHub 下载文件。'
	fi
}

# 构造下载 URL（支持镜像加速）
build_archive_url() {
	local url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${REPO_BRANCH}"
	if [[ -n "$GITHUB_MIRROR" ]]; then
		# 去掉镜像地址末尾的斜杠
		url="${GITHUB_MIRROR%/}/${url}"
	fi
	echo "$url"
}

# 从 GitHub 下载并解压到临时目录，返回应用源目录路径
download_and_extract() {
	local archive_url tmp_dir archive_root source_dir

	archive_url="$(build_archive_url)"
	tmp_dir="$(mktemp -d)"

	# 注册临时目录清理
	_TMP_DIR="$tmp_dir"
	trap 'rm -rf "${_TMP_DIR:-}"' EXIT

	log '正在从 GitHub 下载应用包...'
	info "下载地址: ${archive_url}"

	if ! "${DOWNLOAD_CMD[@]}" "$archive_url" | tar -xz -C "$tmp_dir" 2>/dev/null; then
		fail '下载或解压失败，请检查网络连接或 GitHub 访问是否正常。'
	fi

	archive_root="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)"
	[[ -n "$archive_root" ]] || fail '未能确定解压后的仓库目录。'

	source_dir="$archive_root/apps/${APP_NAME}"
	if [[ ! -d "$source_dir" ]]; then
		source_dir="$(find "$archive_root" -maxdepth 3 -type d -path "*/apps/${APP_NAME}" -print -quit)"
	fi

	[[ -n "$source_dir" && -d "$source_dir" ]] || fail '未能在压缩包中找到应用目录，请检查仓库结构。'

	# 通过全局变量返回
	_SOURCE_DIR="$source_dir"
	_TMP_DIR="$tmp_dir"
}

# 获取已安装的版本号（从目标目录中查找版本子目录）
get_installed_version() {
	local target_dir="$1"
	if [[ ! -d "$target_dir" ]]; then
		echo ""
		return
	fi
	# 版本目录名通常形如 0.12.2，查找所有版本子目录并取最新
	local versions
	versions="$(find "$target_dir" -mindepth 1 -maxdepth 1 -type d \
		-regex '.*/[0-9]+\.[0-9]+\.[0-9]+.*' \
		-printf '%f\n' 2>/dev/null | sort -V | tail -n1)"
	echo "$versions"
}

# 获取远程最新的版本号（从下载的源目录中查找）
get_remote_version() {
	local source_dir="$1"
	local versions
	versions="$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d \
		-regex '.*/[0-9]+\.[0-9]+\.[0-9]+.*' \
		-printf '%f\n' 2>/dev/null | sort -V | tail -n1)"
	echo "$versions"
}

# 版本号比较：若 $1 < $2 返回 0，否则返回 1
version_lt() {
	[[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

# 验证安装完整性
verify_installation() {
	local target_dir="$1"
	if [[ ! -f "$target_dir/data.yml" ]]; then
		fail '安装验证失败：data.yml 缺失。'
	fi
	local version
	version="$(get_installed_version "$target_dir")"
	if [[ -z "$version" ]]; then
		fail '安装验证失败：未找到任何版本目录。'
	fi
	if [[ ! -f "$target_dir/$version/docker-compose.yml" ]]; then
		fail "安装验证失败：版本 $version 的 docker-compose.yml 缺失。"
	fi
	return 0
}

# --- 安装操作 ---------------------------------------------------------------
do_install() {
	local target_dir="$INSTALL_ROOT/${APP_NAME}"

	if [[ -d "$target_dir" && -f "$target_dir/data.yml" ]]; then
		warn "检测到已存在的安装：$target_dir"
		warn "将覆盖现有文件。如需更新请使用: $0 update"
		printf '是否继续覆盖安装？[y/N] '
		read -r confirm
		[[ "$confirm" =~ ^[Yy]$ ]] || { log '已取消安装。'; exit 0; }
	fi

	download_and_extract

	log "正在安装文件到 $target_dir ..."
	mkdir -p "$INSTALL_ROOT"
	rm -rf "$target_dir"
	mkdir -p "$target_dir"

	cp -a "$_SOURCE_DIR/." "$target_dir/"
	chown -R root:root "$target_dir"

	verify_installation "$target_dir"

	local version
	version="$(get_installed_version "$target_dir")"

	echo ""
	log "${C_BOLD}安装已完成！${C_RESET}"
	info "安装路径: $target_dir"
	info "安装版本: $version"
	info "请在 1Panel 的 应用商店->全部 中手动点击 同步本地应用 以更新应用列表。"
}

# --- 更新操作 ---------------------------------------------------------------
do_update() {
	local target_dir="$INSTALL_ROOT/${APP_NAME}"

	# 检查当前是否已安装
	if [[ ! -d "$target_dir" || ! -f "$target_dir/data.yml" ]]; then
		fail "未检测到已安装的 MaiBot，请先运行: $0 install"
	fi

	local current_version
	current_version="$(get_installed_version "$target_dir")"
	if [[ -z "$current_version" ]]; then
		fail '无法获取当前安装版本。'
	fi
	info "当前已安装版本: $current_version"

	# 下载最新版本
	download_and_extract

	local remote_version
	remote_version="$(get_remote_version "$_SOURCE_DIR")"
	if [[ -z "$remote_version" ]]; then
		fail '无法获取远程最新版本号。'
	fi
	info "远程最新版本: $remote_version"

	# 版本比较
	if [[ "$current_version" == "$remote_version" ]]; then
		log "当前已是最新版本 ($current_version)，无需更新。"
		exit 0
	fi

	if ! version_lt "$current_version" "$remote_version"; then
		warn "当前版本 ($current_version) 高于或等于远程版本 ($remote_version)。"
		printf '是否仍要继续？[y/N] '
		read -r confirm
		[[ "$confirm" =~ ^[Yy]$ ]] || { log '已取消更新。'; exit 0; }
	fi

	log "将从 $current_version 更新到 $remote_version"

	# 执行更新 —— 保留用户数据目录
	log '正在更新应用模板文件...'

	# 更新顶层文件（data.yml, logo.png, README.md 等）
	for f in "$_SOURCE_DIR"/*; do
		local fname
		fname="$(basename "$f")"
		if [[ -f "$f" ]]; then
			cp -f "$f" "$target_dir/$fname"
		fi
	done

	# 添加新版本目录
	if [[ -d "$_SOURCE_DIR/$remote_version" ]]; then
		log "正在安装新版本目录: $remote_version"
		cp -a "$_SOURCE_DIR/$remote_version" "$target_dir/$remote_version"
	fi

	# 清理旧版本目录（保留当前版本和新版本）
	for d in "$target_dir"/*/; do
		local dname
		dname="$(basename "$d")"
		# 如果目录名匹配版本号格式
		if [[ "$dname" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
			if [[ "$dname" != "$remote_version" && "$dname" != "$current_version" ]]; then
				info "清理旧版本目录: $dname"
				rm -rf "$d"
			fi
		fi
	done

	chown -R root:root "$target_dir"

	verify_installation "$target_dir"

	echo ""
	log "${C_BOLD}更新已完成！${C_RESET}"
	info "版本变更: $current_version -> $remote_version"
	info "请在 1Panel 应用商店->已安装 页面中手动更新新版本。"
}

# --- 帮助信息 ---------------------------------------------------------------
show_help() {
	cat <<-EOF

	${C_BOLD}MaiBot 1Panel 应用安装 / 更新脚本 v${SCRIPT_VERSION}${C_RESET}

	${C_BOLD}用法:${C_RESET}
	  $0 [命令]

	${C_BOLD}命令:${C_RESET}
	  install     全新安装（默认）
	  update      更新到最新版本
	  version     显示当前安装版本
	  help        显示此帮助信息

	${C_BOLD}环境变量:${C_RESET}
	  INSTALL_ROOT    安装根目录（默认 /opt/1panel/resource/apps/local）
	  GITHUB_MIRROR   GitHub 镜像加速地址（如 https://ghproxy.com）

	${C_BOLD}示例:${C_RESET}
	  # 全新安装
	  sudo bash $0 install

	  # 更新到最新版本
	  sudo bash $0 update

	  # 使用镜像加速下载
	  sudo GITHUB_MIRROR=https://ghproxy.com bash $0 install

	  # 自定义安装路径
	  sudo INSTALL_ROOT=/custom/path bash $0 install

	EOF
}

# --- 显示版本信息 -----------------------------------------------------------
show_version() {
	local target_dir="$INSTALL_ROOT/${APP_NAME}"
	info "脚本版本: $SCRIPT_VERSION"
	if [[ -d "$target_dir" && -f "$target_dir/data.yml" ]]; then
		local ver
		ver="$(get_installed_version "$target_dir")"
		if [[ -n "$ver" ]]; then
			info "已安装的 MaiBot 版本: $ver"
		else
			warn "无法检测已安装的版本。"
		fi
		info "安装路径: $target_dir"
	else
		info "MaiBot 尚未安装。"
	fi
}

# --- 入口 -------------------------------------------------------------------
main() {
	local action="${1:-install}"

	case "$action" in
		install)
			# 权限检查
			if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
				fail '需要 root 权限，请以 root 身份执行此脚本。'
			fi
			require_command tar
			setup_downloader
			do_install
			;;
		update|upgrade)
			if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
				fail '需要 root 权限，请以 root 身份执行此脚本。'
			fi
			require_command tar
			setup_downloader
			do_update
			;;
		version|--version|-v)
			show_version
			;;
		help|--help|-h)
			show_help
			;;
		*)
			fail "未知命令: $action（使用 '$0 help' 查看帮助）"
			;;
	esac
}

main "$@"
