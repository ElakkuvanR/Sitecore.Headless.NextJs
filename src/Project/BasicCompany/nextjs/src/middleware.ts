/* eslint-disable prettier/prettier */
import { NextRequest, NextResponse } from 'next/server'


export default async function middleware(req: NextRequest): Promise<NextResponse> {
    const response = NextResponse.next()
    response.headers.set('x-sug-country', 'FR')
    return response
}