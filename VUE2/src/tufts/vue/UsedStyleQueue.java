/*
* Copyright 2003-2010 Tufts University  Licensed under the
 * Educational Community License, Version 2.0 (the "License"); you may
 * not use this file except in compliance with the License. You may
 * obtain a copy of the License at
 * 
 * http://www.osedu.org/licenses/ECL-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an "AS IS"
 * BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

package tufts.vue;

import java.util.LinkedList;

/**
 * Stores recently used formatting styles. New or reused styles are kept at the
 * front, while palette cycling reads the queue without removing entries.
 */
final class UsedStyleQueue {
    private static final int MAX_SIZE = 5;

    private final LinkedList<LWComponent> styles = new LinkedList<LWComponent>();
    private int currentIndex = -1;

    synchronized LWComponent add(LWComponent source) {
        if (source == null)
            return null;

        final LWComponent style = createStyleSnapshot(source);
        if (style == null)
            return null;

        final int duplicateIndex = indexOf(style);

        if (duplicateIndex >= 0)
            styles.remove(duplicateIndex);

        styles.addFirst(style);

        if (styles.size() > MAX_SIZE)
            styles.removeLast();

        currentIndex = 0;
        return style;
    }

    synchronized LWComponent first() {
        return styles.isEmpty() ? null : styles.getFirst();
    }

    synchronized LWComponent next() {
        if (styles.isEmpty())
            return null;

        currentIndex = normalize(currentIndex + 1);
        return styles.get(currentIndex);
    }

    synchronized LWComponent previous() {
        if (styles.isEmpty())
            return null;

        currentIndex = normalize(currentIndex - 1);
        return styles.get(currentIndex);
    }

    synchronized boolean isEmpty() {
        return styles.isEmpty();
    }

    private int normalize(int index) {
        final int size = styles.size();
        if (size == 0)
            return -1;
        while (index < 0)
            index += size;
        return index % size;
    }

    private int indexOf(LWComponent style) {
        int index = 0;
        for (LWComponent existing : styles) {
            if (styleEquals(existing, style))
                return index;
            index++;
        }
        return -1;
    }

    private static LWComponent createStyleSnapshot(LWComponent source) {
        final LWComponent style;
        try {
            style = source.getClass().newInstance();
        } catch (Throwable t) {
            tufts.Util.printStackTrace(t);
            return null;
        }

        style.copySupportedProperties(source);
        style.setLabel("usedStyle");
        style.copyStyle(source);
        style.setPersistIsStyle(Boolean.TRUE);
        return style;
    }

    private static boolean styleEquals(LWComponent a, LWComponent b) {
        if (a == b)
            return true;
        if (a == null || b == null)
            return false;

        for (LWComponent.Key key : LWComponent.Key.AllKeys) {
            if (!isStyleKey(key))
                continue;

            final boolean aSupports = a.supportsProperty(key);
            final boolean bSupports = b.supportsProperty(key);
            if (aSupports != bSupports)
                return false;

            if (aSupports) {
                final Object aValue = a.getPropertyValue(key);
                final Object bValue = b.getPropertyValue(key);
                if (aValue == bValue)
                    continue;
                if (aValue == null || !aValue.equals(bValue))
                    return false;
            }
        }

        return true;
    }

    static boolean isStyleKey(LWComponent.Key key) {
        return key != null
            && (key.type == LWComponent.KeyType.STYLE
                || key.type == LWComponent.KeyType.SUB_STYLE);
    }
}
