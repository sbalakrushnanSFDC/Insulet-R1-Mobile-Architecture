trigger TaskTriggerTest on Task (before insert) {
	System.debug('Before insert on task');
}