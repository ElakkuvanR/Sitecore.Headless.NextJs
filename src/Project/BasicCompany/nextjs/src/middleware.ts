/* eslint-disable prettier/prettier */
import { NextResponse } from 'next/server'


export default async function middleware(): Promise<NextResponse> {
    const response = NextResponse.next()
    response.headers.set('x-sug-country', 'FR')
    return response
}