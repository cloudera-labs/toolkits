In case of serious problems, these scripts provide a "nuclear option" for uninstalling ECS in the lab, and assume that at least docker service is running

1) download files to your laptop
2) chmod +x kill-ecs?.sh reboot-ecs.sh
4) Edit the target-hosts-ecs.txt file, replace all instances of "xx" with users lab number
5) run ./kill-ecs1.sh
6) wait for script to finish
7) go to CM>>yourECSCluster>>Actions>>Stop (docker & ECS service must be stopped
8) ./reboot-ecs.sh
10) wait about 5-10 mins
11) run ./kill-ecs2.sh
12) wait for script to finish
13) go to CM>>yourECSCluster>>Actions>>Delete
14) Confirm that ECS cluster is no longer in CM Home
