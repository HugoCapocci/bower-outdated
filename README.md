# bower-outdated
This command will check the bower registry to see if any (or, specific) installed packages are currently outdated

## Install

```bash
npm install -g bower-outdated
```

## Usage

``` bash
cd <path_to_you_project> && bower-outdated
```

## Output

Very similar to `npm outdated` command

![image|alt=output](https://cloud.githubusercontent.com/assets/2291654/22626081/a78678e4-eba5-11e6-946c-044d1a131cf5.png)

* package name is <span style="color:rgb(172, 40, 40)">red</span> if current version (in bower_component) doesn't match the bower.conf requested range version
* latest available version is displayed, it's up to you to decide to update or not (always check the release note first!)

## What's next (Road to 1.0)

* Add flag to display all dependencies, not only outdated
* Optimize processing
