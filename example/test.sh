os_type=$(uname)

mkdir .playground
cd .playground

# make (bare) parent.git repo
mkdir parent
cd parent
git init
echo parent > README
git add README 
git commit -m 'initial parent commit'
mv .git ../parent.git
cd ..
rm -fr parent
cd parent.git
git config --bool core.bare true
cd ..

# make (bare) dep-use-subtrac.git repo
mkdir dep-use-subtrac
cd dep-use-subtrac
git init
echo dep-use-subtrac > README
git add README
git commit -m 'initial dep-use-subtrac commit'
mv .git ../dep-use-subtrac.git
cd ..
rm -fr dep-use-subtrac
cd dep-use-subtrac.git
git config --bool core.bare true
cd ..


# make (bare) dep-use-submodule.git repo
mkdir dep-use-submodule
cd dep-use-submodule
git init
echo dep-use-submodule > README
git add README
git commit -m 'initial dep-use-submodule commit'
mv .git ../dep-use-submodule.git
cd ..
rm -fr dep-use-submodule
cd dep-use-submodule.git
git config --bool core.bare true
cd ..

# repo owner: add dep-use-subtrac as a submodule
git clone parent.git parent
cd parent/
git submodule add ../dep-use-subtrac
git add .gitmodules dep-use-subtrac
git commit -m 'add submodule dep-use-subtrac'
git submodule add ../dep-use-submodule
git add .gitmodules dep-use-submodule
git commit -m 'add submodule dep-use-submodule'
git push origin main 
cd ..
### 初始化完成


### 引入 subtrac
# repo owner: add dep-use-subtrac as a subtrac-enhanced submodule
cd parent/
cp ../../example/.gitsubtrac .
git add .gitsubtrac
git commit -m 'add .gitsubtrac, ready to use subtrac'
../../git-subtrac --auto-exclude update
git push origin main main.trac
cd ..


# repo contributor: clone and make local change in dep-use-subtrac
git clone --recurse-submodules parent.git another-parent
cd another-parent
cd dep-use-subtrac
git checkout main
echo 'local change' >> README
git commit -m 'locally patch dep-use-subtrac' README
cd ..
git commit -m 'record change in parent' dep-use-subtrac
../../git-subtrac --auto-exclude update
## 调整 dep-use-subtrac 的 url，指到主仓库
git config submodule.dep.url .
if [[ "$os_type" == 'Darwin' ]]; then
    # macOS
    sed -i '' 's|url = ../dep-use-subtrac|url = .|g' .gitmodules
elif [[ "$os_type" == 'Linux' ]] || [[ "$os_type" =~ 'MINGW' ]] || [[ "$os_type" =~ 'CYGWIN' ]]; then
    # Linux 或 Windows 中的 Unix 风格 shell
    sed -i 's|url = ../dep-use-subtrac|url = .|g' .gitmodules
else
    echo "Unsupported OS, please use macOS, Linux, or Unix-style shell in Windows."
fi

git add .gitmodules
git commit -m 'change dep-use-subtrac url to .'
git push origin main main.trac
cd ..


# repo contributor2: clone 
git clone --recurse-submodules parent.git another-parent2

# upstream change (submodule remote有更新)
git clone dep-use-subtrac.git dep-use-subtrac
cd dep-use-subtrac
echo 'upstream change' >> UPSTREAM_CHANGE
git add UPSTREAM_CHANGE
git commit -m 'upstream change' 
git push origin main
cd ..

### 获取更新
# merge/rebase parent/dep-use-subtrac after upstream change
git clone --recurse-submodules parent.git another-parent3
cd another-parent3
cd dep-use-subtrac
git config remote.origin.url /Users/wengjialin/opensource/git-subtrac/.playground/dep-use-subtrac # reset dep-use-subtrac url 看看怎么方便自动化 TODO
git fetch 
git branch -f main HEAD
git checkout main
git rebase origin/main
cd ..
git commit -m 'record change2 in parent' dep-use-subtrac
../../git-subtrac --auto-exclude update
git push origin main main.trac
cd ..


git clone --recurse-submodules parent.git another-parent4
