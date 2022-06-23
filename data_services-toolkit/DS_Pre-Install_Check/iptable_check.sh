# Check Iptables
iptables -L > /tmp/iptables.txt
diff /tmp/iptables.txt /tmp/virgin_iptable.txt > iptable_diff.txt
[ -s /tmp/iptable_diff.txt ] && echo "iptables need to be cleared" || echo "clean iptables"