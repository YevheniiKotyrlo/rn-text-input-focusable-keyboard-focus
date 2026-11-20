/**
 * A TextInput between two buttons, kept out of keyboard focus with tabIndex={-1}, and another with
 * focusable={false}. With a hardware keyboard, Tab from the first button should go to the second button.
 *
 * @format
 */

import { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

function Button({ label }: { readonly label: string }) {
  const [focused, setFocused] = useState(false);
  return (
    <Pressable
      accessibilityLabel={label}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={[styles.button, focused && styles.focused]}
    >
      <Text style={styles.buttonText}>{label}</Text>
    </Pressable>
  );
}

function App() {
  return (
    <View style={styles.screen}>
      <Text style={styles.caption}>
        Press Tab with a hardware keyboard. From the first button, Tab
        should go to the second button.
      </Text>
      <Button label="first button" />
      <TextInput
        accessibilityLabel="input with tabIndex -1"
        placeholder="tabIndex={-1}"
        placeholderTextColor="#666666"
        tabIndex={-1}
        style={styles.input}
      />
      <TextInput
        accessibilityLabel="input with focusable false"
        focusable={false}
        placeholder="focusable={false}"
        placeholderTextColor="#666666"
        style={styles.input}
      />
      <Button label="second button" />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: 'white',
    paddingHorizontal: 24,
    paddingTop: 64,
    gap: 16,
  },
  caption: {
    color: 'black',
    fontSize: 16,
  },
  button: {
    alignSelf: 'flex-start',
    backgroundColor: '#eeeeee',
    borderColor: '#eeeeee',
    borderWidth: 4,
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  focused: {
    borderColor: '#d81b60',
  },
  buttonText: {
    color: 'black',
    fontSize: 16,
  },
  input: {
    borderColor: '#999999',
    borderWidth: 1,
    color: 'black',
    fontSize: 16,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
});

export default App;
