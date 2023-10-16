#!/bin/sh
# A more helpful replacement for 'git submodule update --init'.
#
# It leaves the remote 'origin' pointing at the upstream projects, but can
# use local git-subtrac branches as a data source so that most of the time
# it doesn't actually need to fetch from the upstream.
#
# Use this whenever you want to get your submodules back in sync.
#
set -e
cd "$(dirname "$0")"  # move to git worktree root
topdir="$PWD"  # absolute path of git worktree root

# For initial 'git submodule update', the --no-fetch option is ignored,
# and it tries to talk to the origin repo for no good reason. Let's override
# the origin repo URL to fool git into not doing that.
# 当你首次运行 git submodule update 命令时，尽管你使用了 --no-fetch 选项，
# Git 仍然会尝试从原始的远程仓库（origin repo）获取数据。
# 为了避免 Git 尝试从原始的远程仓库获取数据，你可以更改子模块的远程仓库 URL。
# 这会"欺骗" Git，使其认为远程仓库的位置已经改变，从而避免不必要的数据获取。
git submodule status | while read -r commit path junk; do
	git submodule init -- "$path"
done
git config --local --get-regexp '^submodule\..*\.url$' | while read k v; do
    git config "$k" .
done

# In each submodule, make sure info/alternates is set up to retrieve
# objects directly from the parent repo (git-subtrac objects), bypassing
# the need to fetch anything. If someone has previously checked out a
# submodule without setting these values, this will fix them up.
# 在每个子模块中设置 info/alternates 文件，以便从父仓库（在这种情况下，是 git-subtrac 对象）
# 直接检索 Git 对象，从而避免任何需要获取（fetch）的操作。
# 在 Git 中，info/alternates 文件是一种机制，它允许一个仓库直接从另一个仓库的对象数据库中读取对象，
# 而无需将这些对象复制或移动到自己的对象数据库中。这在一些情况下可能很有用，例如当你想节省磁盘空间或提高性能时。
# 如果有人以前签出了一个子模块而没有设置这些值，这将修复它们。
for config in .git/modules/*/config; do
	[ -f "$config" ] || continue

	dir=$(dirname "$config")
	echo "$topdir/.git/objects" >"$dir/objects/info/alternates"
done

# Make sure any remaining submodules have been checked out at least once,
# referring to the toplevel repo for all objects.
# 这段代码的目的是确保所有剩余的子模块至少被检出一次，所有对象的引用都指向顶级仓库。
#
# TODO(apenwarr): --merge is not always the right option.
#  eg. when checking out old revisions, we'd rather just roll the submodule
#  backwards too. But git submodule doesn't have a good way to do that
#  safely, so after a checkout, you can run git-stash-all.sh by hand to
#  rewind the submodules.
# --merge 并不总是正确的选项。
#   例如，当检出旧的修订版本时，我们宁愿让子模块也回滚到旧版本。
#   然而，git submodule 没有一个好的方法来安全地做这个操作，
#   所以在检出之后，你可以手动运行 git-stash-all.sh 来回滚子模块。
# git submodule update --init --no-fetch --reference="$PWD" --recursive --merge 命令执行了以下操作：
#   --init：初始化子模块。如果子模块还没有初始化，这个选项会初始化它们。
#   --no-fetch：不获取新的数据。这个选项告诉 Git 不要从远程仓库获取新的数据。
#   --reference="$PWD"：使用当前工作目录作为引用。这个选项告诉 Git 使用当前工作目录作为所有 Git 对象的引用。
#   --recursive：递归处理所有子模块。如果你的子模块中还有子模块，这个选项会告诉 Git 也要处理这些子模块。
#   --merge：合并子模块的改变。这个选项告诉 Git 如果子模块的当前提交和新的提交有冲突，应该尝试合并这些更改。
git submodule update --init --no-fetch --reference="$PWD" --recursive --merge

# Make sure all submodules are *now* (after initial checkout) using the
# latest URL from .gitmodules for their 'origin' URL.
# 这段代码的目的是确保所有子模块在初始检出（initial checkout）后都使用 .gitmodules 文件中最新的 URL 作为他们的 'origin' URL。
# 即恢复到原始状态
#   --quiet：安静模式。在执行操作时不输出任何信息。
#   sync：同步操作。这个命令将更新每个子模块的 'origin' URL，以匹配 .gitmodules 文件中的 URL。
#   --recursive：递归处理所有子模块。如果你的子模块中还有子模块，这个选项会告诉 Git 也要处理这些子模块。
git submodule --quiet sync --recursive

git submodule status --cached | while read -r commit path junk; do
	# fix superproject conflicts caused by trying to merge submodules,
	# if any. These happen when two different commits try to change the
	# same submodule in incompatible ways. To resolve it, we'll check out
	# the first one and try to git merge the second. (Why git can't just
	# do this by itself is... one of the many problems with submodules.)
    # 修复由于尝试合并子模块而导致的超级项目冲突，
    # 如果有的话。这些冲突发生在两个不同的提交试图以不兼容的方式更改同一个子模块时。
    # 为了解决这个问题，我们将检出第一个提交，并尝试将第二个提交进行 git 合并。
    # （为什么 Git 不能自动做这个操作是……这是使用子模块的众多问题之一。）
	cid2=
	cid3=
	git ls-files --unmerged -- "$path" | while read -r mode hash rev junk; do
		if [ "$rev" = "2" ]; then
			(cd "$path" && git checkout "$hash" -- || true)
			cid2=$hash
		fi
		if [ "$rev" = "3" ]; then
			cid3=$hash
			(cd "$path" && git merge "$hash" -- || true)
			git add -- "$path"
		fi
	done

	commit=${commit#-}
	commit=${commit#+}
	(
		cd "$path"

		main=$(git rev-parse --verify --quiet main || true)
		head=$(git rev-parse --verify HEAD)

		if [ -n "$main" ] &&
		   ! git merge-base main "$commit" >/dev/null; then
			# main and $commit have no common history.
			# It's probably dangerous. Move it aside.
			git branch -f -m main main.probably-broken
		fi

		# update --merge can't rewind the branch, only move it
		# forward. Give a warning if we notice this problem.
		if [ "$head" != "$commit" ]; then
			echo "$path:" >&2
			echo "  Couldn't checkout non-destructively." >&2
			echo "  You can try to fix it by hand, or" >&2
			echo "  use git-stash-all.sh if you want to force it." >&2
		fi
	)
done