import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.MOLTBOOK_API_URL || 'https://www.moltbook.com/api/v1';

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { id } = await params;

    const response = await fetch(`${API_BASE}/posts/${id}/downvote`, {
      method: 'POST',
      headers: { Authorization: authHeader },
    });

    // Handle empty response body (e.g., 204 No Content)
    const contentType = response.headers.get('content-type');
    if (response.status === 204 || !contentType?.includes('application/json')) {
      return new NextResponse(null, { status: response.status });
    }

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
