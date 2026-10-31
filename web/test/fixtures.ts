// Reads the fixtures that Packages/IntegrationTests/WebFixtureTests.swift writes from the
// Swift code. Regenerate them there, never by hand.
import { readFileSync } from 'node:fs'

const directory = new URL('./fixtures/', import.meta.url)

export const fixtureBytes = (name: string) => new Uint8Array(readFileSync(new URL(name, directory)))

export const fixtureText = (name: string) => readFileSync(new URL(name, directory), 'utf8')

export const fixture = <Value>(name: string) => JSON.parse(fixtureText(name)) as Value
