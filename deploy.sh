#/bin/sh

echo "#### go to branch - blog"
git checkout blog

echo "#### init the themes"
git submodule init
git submodule update

echo "#### deploy content to 'public/'"
hugo

dest="hugo-build-$RANDOM"
echo "#### INFO: temp directory of public is: $dest"

# handle folder public/ resources/ themes/
#
echo "#### move public/ to /var/tmp/$dest"
mv public/ /var/tmp/$dest

echo "#### remove cache folder resources"
rm -r resources/

echo "#### deinit submodule to clear folder themes"
git submodule deinit --all


echo "#### go to branch - master"
git checkout master

echo "#### remove anything except .git/"
to_rm=$(ls --almost-all | grep -v -E -e "^\.git$")
rm -r $to_rm

echo "#### move /var/tmp/$dest/* to ./"
to_mv=$(ls --almost-all /var/tmp/$dest/)
for f in $to_mv ; {
    mv /var/tmp/$dest/$f ./
}

echo "#### remove empty directory /var/tmp/$dest"
rmdir /var/tmp/$dest/

echo "#### stash and commit"
commit_msg="deploy: $(date +'%m/%d/%Y %H:%M')"
git commit -a -m "$commit_msg"

