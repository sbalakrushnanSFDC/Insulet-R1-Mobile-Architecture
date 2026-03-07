/**
 * @description Trigger handler base class.
 * Please see https://confluence.insulet.com/display/NASFL/Writing+Apex+Triggers for details
 * on writing Apex Triggers using this handler.
 */
public virtual without sharing class TriggerHandler {
    // static map of handlername, times run() was invoked
    private static Map<String, LoopCount> loopCountMap;
    private static Set<String> bypassedHandlers;

    @TestVisible
    private static TriggerOperation triggerContext;

    @SuppressWarnings('PMD.EmptyStatementBlock')
    @TestVisible
    protected TriggerHandler() { }

    static {
        loopCountMap = new Map<String, LoopCount>();
        bypassedHandlers = new Set<String>();
    }

    /**
     * @description Execute method that should be invoked in your trigger
     */
    public void execute() {
        if(!validateRun()) {
            return;
        }

        addToLoopCount();

        TriggerOperation context = triggerContext != null ? triggerContext : Trigger.operationType;
        switch on context {
            when BEFORE_INSERT {
                this.beforeInsert(Trigger.new);
            }
            when BEFORE_UPDATE {
                this.beforeUpdate(Trigger.newMap, Trigger.oldMap);
            }
            when BEFORE_DELETE {
                this.beforeDelete(Trigger.oldMap);
            }
            when AFTER_INSERT {
                this.afterInsert(Trigger.newMap);
            }
            when AFTER_UPDATE {
                this.afterUpdate(Trigger.newMap, Trigger.oldMap);
            }
            when AFTER_DELETE {
                this.afterDelete(Trigger.oldMap);
            }
            when AFTER_UNDELETE {
                this.afterUndelete(Trigger.newMap);
            }
        }
        this.andFinally();
    }

    /**
     * @description Set the maximum number of times this handler can be run in a single transaction.
     * @param max Max count that should be set
     */
    public void setMaxLoopCount(Integer max) {
        String handlerName = getHandlerName();
        if(!TriggerHandler.loopCountMap.containsKey(handlerName)) {
            TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
        } else {
            TriggerHandler.loopCountMap.get(handlerName).setMax(max);
        }
    }

    /**
     * @description clears the max loop count for this handler
     */
    public void clearMaxLoopCount() {
        this.setMaxLoopCount(-1);
    }

    /**
     * @description Bypass handler for the current transaction
     * @param handlerName Name of the handler to bypass
     */
    public static void bypass(String handlerName) {
        TriggerHandler.bypassedHandlers.add(handlerName);
    }

    /**
     * @description Clear bypass for handler for the current transaction
     * @param handlerName Name of the handler to clear bypass for
     */
    public static void clearBypass(String handlerName) {
        TriggerHandler.bypassedHandlers.remove(handlerName);
    }

    /**
     * @description Check if handler is bypassed for the current transaction
     * @param handlerName Name of the handler to check
     * @return true if handler is bypassed, false otherwise
     */
    public static Boolean isBypassed(String handlerName) {
        return TriggerHandler.bypassedHandlers.contains(handlerName);
    }

    /**
     * @description Clear all bypasses for the current transaction
     */
    public static void clearAllBypasses() {
        TriggerHandler.bypassedHandlers.clear();
    }

    // increment the loop count
    @TestVisible
    private void addToLoopCount() {
        String handlerName = getHandlerName();
        if(TriggerHandler.loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName).increment();
            if(exceeded) {
                Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
                throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
            }
        }
    }

    // make sure this trigger should continue to run
    @TestVisible
    private Boolean validateRun() {
        return !BypassTriggerUtil.isTriggerBypassEnabled() && !TriggerHandler.bypassedHandlers.contains(getHandlerName());
    }

    @TestVisible
    private String getHandlerName() {
        return this.toString().substringBefore(':');
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void beforeInsert(List<SObject> newRecords) {}

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void beforeUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {}

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void beforeDelete(Map<Id, SObject> deletedRecordsMap) {}

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void afterInsert(Map<Id, SObject> newRecordsMap) {}

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {}

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void afterDelete(Map<Id, SObject> deletedRecordsMap) {}

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void afterUndelete(Map<Id, SObject> undeletedRecordsMap) {}
    // runs after every context

    @SuppressWarnings('PMD.EmptyStatementBlock')
    protected virtual void andFinally() {}

    // inner class for managing the loop count per handler
    @TestVisible
    private class LoopCount {
        private Integer max;
        private Integer count;

        /**
         * @description Constructor to initialize loop count with default values
         */
        public LoopCount() {
            this.max = 5;
            this.count = 0;
        }

        /**
         * @description Constructor to initialize loop count with custom values
         * @param max Max count that should be set
         */
        public LoopCount(Integer max) {
            this.max = max;
            this.count = 0;
        }

        /**
         * @description Increment the loop count
         * @return true if the max count has been exceeded, false otherwise
         */
        public Boolean increment() {
            this.count++;
            return this.exceeded();
        }

        /**
         * @description Check if loop count has been exceeded
         * @return true if loop count exceeded, false otherwise
         */
        public Boolean exceeded() {
            return this.max >= 0 && this.count > this.max;
        }

        /**
         * @description Get the max loop count
         * @return max loop count
         */
        public Integer getMax() {
            return this.max;
        }

        /**
         * @description Get the current loop count
         * @return current loop count
         */
        public Integer getCount() {
            return this.count;
        }

        /**
         * @description Set the max loop count
         * @param max Max count that should be set
         */
        public void setMax(Integer max) {
            this.max = max;
        }
    }

    /**
     * @description exception class
     */
    public class TriggerHandlerException extends Exception {}
}